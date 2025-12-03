defmodule Wik.Accounts.GroupUserRelation do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "group_user_relations"
    repo Wik.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:group_id, :user_id]
      change relate_actor(:author)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    policy action_type(:read) do
      # TODO: authorize only if actor and GroupUserRelation have 1 or more groups in common
      authorize_if always()
    end

    policy action_type(:destroy) do
      # TODO: authorize only if actor is group author 
      authorize_if always()
    end
  end

  attributes do
    timestamps()
  end

  relationships do
    belongs_to :author, Wik.Accounts.User do
      allow_nil? false
      # public? true
    end

    belongs_to :group, Wik.Accounts.Group, primary_key?: true, allow_nil?: false
    belongs_to :user, Wik.Accounts.User, primary_key?: true, allow_nil?: false
  end

  identities do
    identity :unique_group_user_relation, [:group_id, :user_id]
  end
end
