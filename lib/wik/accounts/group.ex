defmodule Wik.Accounts.Group do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Wik.Notifiers.ResourceMutation],
    extensions: [AshEvents.Events]

  defimpl String.Chars do
    def to_string(group), do: group.title
  end

  postgres do
    table "groups"
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
      accept [:title, :text, :slug]
      primary? true
      require_atomic? false
    end

    read :read do
      primary? true
    end

    create :create do
      accept [:title, :text]
      primary? true
      change relate_actor(:author)

      change fn cs, _ctx ->
        cs
        |> Utils.Slugify.maybe_set_and_ensure_unique_slug()
      end

      change fn changeset, context ->
        Ash.Changeset.manage_relationship(
          changeset,
          :users,
          context.actor,
          type: :append_and_remove,
          authorize?: false
        )
      end
    end

    destroy :destroy do
      primary? true
      change cascade_destroy(:group_user_relations, after_action?: false)
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via(:users)
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via(:author)
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:author)
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

    has_many :pages, Wik.Wiki.Page do
      destination_attribute :group_id
    end

    has_many :group_user_relations, Wik.Accounts.GroupUserRelation do
      destination_attribute :group_id
    end

    many_to_many :users, Wik.Accounts.User do
      through Wik.Accounts.GroupUserRelation
      source_attribute :id
      source_attribute_on_join_resource :group_id
      destination_attribute :id
      destination_attribute_on_join_resource :user_id
    end
  end

  calculations do
    calculate :last_updated_pages,
              {:array, :map},
              {Wik.Calculations.LastUpdatedPages, limit: 5} do
      argument :limit, :integer do
        default 5
        allow_nil? false
      end
    end
  end

  aggregates do
    count :pages_count, :pages do
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug], eager_check_with: Wik.Accounts
  end
end

defmodule Wik.Calculations.LastUpdatedPages do
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    # Set default limit to 5 if not provided
    {:ok, Keyword.put_new(opts, :limit, 5)}
  end

  @impl true
  def load(_query, _opts, _context) do
    [pages: [:title, :updated_at, :slug, author: [:email]]]
  end

  @impl true
  def calculate(groups, _opts, context) do
    limit = Map.get(context.arguments, :limit, 5)

    Enum.map(groups, fn group ->
      case group.pages do
        %Ash.NotLoaded{} ->
          []

        pages ->
          pages
          |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
          |> Enum.take(limit)
          |> Enum.map(fn page ->
            %{
              title: page.title,
              author: page.author,
              slug: page.slug,
              updated_at: page.updated_at
            }
          end)
      end
    end)
  end

  def type(_opts), do: {:array, :map}
end
