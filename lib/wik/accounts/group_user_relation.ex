defmodule Wik.Accounts.GroupUserRelation do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "group_user_relations"
    repo Wik.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:group_id, :user_id]

      change fn cs, ctx ->
        author = ctx.actor || raise "no actor in context"
        Ash.Changeset.manage_relationship(cs, :author, author, type: :append_and_remove)
      end
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
