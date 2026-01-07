defmodule Wik.Wiki.PageTree do
  @moduledoc """
  Materialized-path tree nodes for wiki pages.

  Each node represents a path (e.g. "Library/Guided") and may or may not
  reference a concrete page record yet.
  """

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Wiki,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Wik.Notifiers.PageTreeMutation]

  require Ash.Query

  alias Wik.Wiki.PageTree.Utils

  postgres do
    table "pages_tree"
    repo Wik.Repo

    references do
      reference :group, on_delete: :delete
      reference :page, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :path, :group_id, :page_id]
      primary? true
    end

  update :update do
    accept [:title, :path, :page_id]
    primary? true
    require_atomic? false
  end
  end

  changes do
    change fn changeset, _ctx ->
      path = Ash.Changeset.get_attribute(changeset, :path)

      case Utils.normalize_path(path) do
        {:ok, normalized_path, title} ->
          changeset
          |> Ash.Changeset.change_attribute(:path, normalized_path)
          |> Ash.Changeset.change_attribute(:title, title)

        {:error, message} ->
          Ash.Changeset.add_error(changeset, message)
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :path, :string, allow_nil?: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      allow_nil? false
      public? true
    end

    belongs_to :page, Wik.Wiki.Page do
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_group_path, [:group_id, :path], eager_check_with: Wik.Accounts
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:group, :users])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:group, :users])
    end
  end
end
