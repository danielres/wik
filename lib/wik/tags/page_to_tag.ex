defmodule Wik.Tags.PageToTag do
  @moduledoc """
  Join between pages and tags (group-scoped).
  """

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Tags,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Wik.Notifiers.ResourceMutation]

  postgres do
    table "pages_to_tags"
    repo Wik.Repo

    references do
      reference :group, on_delete: :delete
      reference :page, on_delete: :delete
      reference :tag, on_delete: :delete
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if relates_to_actor_via([:group, :users])
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      allow_nil? false
      public? true
    end

    belongs_to :page, Wik.Wiki.Page do
      allow_nil? false
      public? true
    end

    belongs_to :tag, Wik.Tags.Tag do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_page_tag, [:group_id, :page_id, :tag_id]
  end
end
