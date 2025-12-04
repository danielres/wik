defmodule Wik.Wiki.Backlink do
  @moduledoc """
  Backlink edges between pages within a group.

  A backlink points from a `source_page` to a target identified by `target_slug`,
  optionally linked to an existing `target_page` when the page exists.
  """

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Wiki,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "backlinks"
    repo Wik.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:group_id, :source_page_id, :target_slug, :target_page_id]
      primary? true
    end

    update :update do
      accept [:target_page_id]
      primary? true
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :target_slug, :string, allow_nil?: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      allow_nil? false
      public? true
    end

    belongs_to :source_page, Wik.Wiki.Page do
      allow_nil? false
      public? true
    end

    belongs_to :target_page, Wik.Wiki.Page do
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_source_target, [:group_id, :source_page_id, :target_slug]
  end

  policies do
    policy action_type(:create) do
      authorize_if relates_to_actor_via([:group, :users])
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
end
