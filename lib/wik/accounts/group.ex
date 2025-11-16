defmodule Wik.Accounts.Group do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "groups"
    repo Wik.Repo
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

    create :create do
      accept [:title, :text]
      primary? true
      change relate_actor(:author)

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
    attribute :text, :string, allow_nil?: true, public?: true
    timestamps()
  end

  relationships do
    belongs_to :author, Wik.Accounts.User do
      allow_nil? false
      public? true
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
end
