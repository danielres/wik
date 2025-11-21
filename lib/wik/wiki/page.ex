defmodule Wik.Wiki.Page do
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
    event_log Wik.Events.Event

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
      accept [:title, :text, :slug]
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

      change fn cs, _ctx ->
        cs |> Utils.Slugify.maybe_set_and_ensure_unique_slug()
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
  end

  identities do
    identity :unique_group_slug, [:group_id, :slug], eager_check_with: Wik.Accounts
  end
end
