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

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:users)
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

    many_to_many :users, Wik.Accounts.User do
      through Wik.Accounts.GroupUserRelation
      source_attribute :id
      source_attribute_on_join_resource :group_id
      destination_attribute :id
      destination_attribute_on_join_resource :user_id
    end
  end
end
