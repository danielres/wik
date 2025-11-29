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
    def to_string(page), do: page.title
  end

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

    end

    destroy :destroy do
      primary? true
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
  end

  aggregates do
    count :versions_count, :versions do
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

end
