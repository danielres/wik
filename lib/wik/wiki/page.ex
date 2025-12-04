defmodule Wik.Wiki.Page do
  @moduledoc """
  Represents a wiki page within a group.

  Pages are the primary content units in the application. Each page:
  - Belongs to a specific group
  - Has a unique slug within its group
  - Contains markdown or text content
  - Has an author (creator)
  - Tracks all changes through event logging for version history

  ## Authorization
  - Users can read pages in groups they belong to
  - Users can create/update/destroy pages in their groups
  """

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Wiki,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Wik.Notifiers.ResourceMutation],
    extensions: [AshEvents.Events]

  defimpl String.Chars do
    @doc """
Use the page's title as its string representation.
"""
@spec to_string(Wik.Wiki.Page.t()) :: String.t()
def to_string(page), do: page.title
  end

  require Logger

  postgres do
    table "pages"
    repo Wik.Repo
  end

  events do
    # Specify your event log resource
    event_log Wik.Versions.Version

    # Optionally ignore certain actions. This is mainly used for actions
    # that are kept around for supporting previous event versions, and
    # are configured as replay_overrrides in the event log (see above).
    # ignore_actions [:old_create_v1]

    # Optionally specify version numbers for actions
    # current_action_versions create: 2, update: 3, destroy: 2
  end

  actions do
    defaults []

    update :update do
      accept [:title, :text]
      primary? true
      require_atomic? false

      change fn changeset, _ctx ->
        text_changed? = Ash.Changeset.changing_attribute?(changeset, :text)

        changeset
        |> Ash.Changeset.after_transaction(fn _changeset, result ->
          case result do
            {:ok, page} ->
              if text_changed? do
                safe_backlink(fn -> Wik.Wiki.Backlink.Utils.rebuild_for_page(page, _changeset) end, "rebuild", page)
              end

              {:ok, page}

            other ->
              other
          end
        end)
      end
    end

    read :read do
      primary? true
    end

    changes do
      change fn changeset, _context ->
               case Ash.Changeset.fetch_change(changeset, :title) do
                 {:ok, title} when is_binary(title) ->
                   capitalized = String.capitalize(title)
                   Ash.Changeset.force_change_attribute(changeset, :title, capitalized)

                 _ ->
                   changeset
               end
             end,
             on: [:create, :update]

      change fn cs, _ctx ->
               cs |> trim_text()
             end,
             on: [:create, :update]

      change fn cs, _ctx ->
               cs |> collapse_blank_lines()
             end,
             on: [:update]

      change fn cs, _ctx ->
               cs |> set_slug()
             end,
             on: [:create]

      change fn cs, _ctx ->
               cs |> set_header()
             end,
             on: [:create, :update]

      change fn cs, _ctx ->
               cs |> update_title_from_header()
             end,
             on: [:update]
    end

    create :create do
      accept [:title, :text]
      primary? true

      change relate_actor(:author)

      change fn changeset, context ->
        # Access source_context.shared instead of using get_in on context directly  
        group_id = get_in(context.source_context, [:shared, :current_group_id])

        if group_id do
          Ash.Changeset.manage_relationship(
            changeset,
            :group,
            group_id,
            type: :append_and_remove
          )
        else
          Ash.Changeset.add_error(changeset, "No current group set")
        end
      end

      change fn changeset, _ctx ->
        text_changed? = Ash.Changeset.changing_attribute?(changeset, :text)

        changeset
        |> Ash.Changeset.after_transaction(fn _changeset, result ->
          case result do
            {:ok, page} ->
              if text_changed? do
                safe_backlink(fn -> Wik.Wiki.Backlink.Utils.rebuild_for_page(page, _changeset) end, "rebuild", page)
              end

              safe_backlink(fn -> Wik.Wiki.Backlink.Utils.reconcile_new_target(page) end, "reconcile", page)
              {:ok, page}

            other ->
              other
          end
        end)
      end
    end

    destroy :destroy do
      primary? true

      change fn changeset, _ctx ->
        changeset
        |> Ash.Changeset.after_transaction(fn _changeset, result ->
          case result do
            {:ok, page} ->
              safe_backlink(fn -> Wik.Wiki.Backlink.Utils.delete_for_page(page) end, "delete", page)
              {:ok, page}

            other ->
              other
          end
        end)
      end
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via([:group, :users])
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via([:group, :users])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:group, :users])
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    attribute :text, :string, allow_nil?: true, public?: true
    timestamps()
  end

  relationships do
    belongs_to :author, Wik.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :group, Wik.Accounts.Group do
      allow_nil? false
      public? true
    end

    has_many :versions, Wik.Versions.Version do
      destination_attribute :record_id
      source_attribute :id
      filter expr(resource == Wik.Wiki.Page)
    end

    has_many :backlinks, Wik.Wiki.Backlink do
      destination_attribute :target_page_id
    end
  end

  aggregates do
    count :versions_count, :versions do
      public? true
    end

    count :backlinks_count, :backlinks do
      public? true
    end
  end

  identities do
    identity :unique_group_slug, [:group_id, :slug], eager_check_with: Wik.Accounts
  end

  def trim_text(cs) do
    text = Ash.Changeset.get_attribute(cs, :text)
    trimmed = (text || "") |> String.trim()
    Ash.Changeset.change_attribute(cs, :text, trimmed)
  end

  def collapse_blank_lines(cs) do
    text = Ash.Changeset.get_attribute(cs, :text)
    collapsed = (text || "") |> String.replace("<br />\n\n", "")
    Ash.Changeset.change_attribute(cs, :text, collapsed)
  end

  @doc """
  Set the changeset's `:slug` attribute to the canonical form of its `:title`.
  
  ## Parameters
  
    - changeset: an `Ash.Changeset` from which the `:title` attribute is read.
  
  """
  @spec set_slug(Ash.Changeset.t()) :: Ash.Changeset.t()
  def set_slug(changeset) do
    title = Ash.Changeset.get_attribute(changeset, :title)
    slug = Wik.Wiki.Page.Utils.canonical_slug(title)
    Ash.Changeset.change_attribute(changeset, :slug, slug)
  end

  @doc """
  Ensure the changeset's `:text` begins with a top-level header derived from the `:title`.
  
  If the `:text` already starts with "# " it is left unchanged. Otherwise the function prepends a header line "# <title>" followed by two newlines and the original text (or "<br />" if text is nil).
  
  ## Parameters
  
    - changeset: An `Ash.Changeset` for a `Wik.Wiki.Page` containing `:title` and optional `:text`.
  
  ## Examples
  
      iex> cs = Ash.Changeset.for_create(Wik.Wiki.Page, title: "Hello", text: "Body")
      iex> cs |> Wik.Wiki.Page.set_header() |> Ash.Changeset.get_attribute(:text)
      "# Hello\n\nBody"
  
  """
  @spec set_header(Ash.Changeset.t()) :: Ash.Changeset.t()
  def set_header(changeset) do
    text = Ash.Changeset.get_attribute(changeset, :text)
    has_header? = (text || "") |> String.slice(0, 2) == "# "

    if has_header? do
      changeset
    else
      title = Ash.Changeset.get_attribute(changeset, :title)
      Ash.Changeset.change_attribute(changeset, :text, "# #{title}\n\n#{text || "<br />"}")
    end
  end

  @doc """
  Updates the changeset's `:title` from a leading Markdown header in `:text` if present.
  
  If `:text` begins with "# " followed by a header line, extracts that header (first line without the leading `# `, trimmed) and sets it as the `:title` on the changeset. Otherwise returns the unchanged changeset.
  
  ## Parameters
  
    - changeset: an Ash.Changeset for a Page that may contain `:text` and `:title` attributes.
  
  ## Examples
  
      iex> cs = Ash.Changeset.for_create(Page, %{text: "# New Title\\nBody"})
      iex> Wik.Wiki.Page.update_title_from_header(cs).changes.title
      "New Title"
  
  """
  @spec update_title_from_header(Ash.Changeset.t()) :: Ash.Changeset.t()
  def update_title_from_header(changeset) do
    text = Ash.Changeset.get_attribute(changeset, :text)
    has_header? = (text || "") |> String.slice(0, 2) == "# "

    if has_header? do
      header =
        text
        |> String.split("\n", parts: 2)
        |> hd()
        |> String.trim_leading("# ")
        |> String.trim()

      Ash.Changeset.change_attribute(changeset, :title, header)
    else
      changeset
    end
  end

  defp safe_backlink(fun, action, page) do
    fun.()
  rescue
    exception ->
      Logger.warning(
        "Backlink #{action} failed for page #{inspect(page.id)}: #{Exception.message(exception)}"
      )

      {:ok, page}
  end
end