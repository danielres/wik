defmodule Wik.Accounts.GroupUserRelation do
  @moduledoc """
  Represents the many-to-many relationship between groups and users.

  This resource manages which users belong to which groups, including
  tracking who added the user to the group (the author).

  ## Authorization
  - Users can read relations for groups they belong to
  - Only group authors can remove members from groups
  """

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
    # Users can read group-user relations for groups they are members of
    policy action_type(:read) do
      # Allow reading if the actor is related to the group through group_user_relations
      authorize_if relates_to_actor_via([:group, :users])
    end

    # Only group authors can remove members from groups
    policy action_type(:destroy) do
      # Allow destroy if actor is the author of the group
      authorize_if relates_to_actor_via([:group, :author])
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
