defmodule Wik.Tags.Tag do
  @moduledoc """
  Tag resource (group-scoped). Names are downcased and unique per group.
  """

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Tags,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Wik.Notifiers.ResourceMutation]

  postgres do
    table "tags"
    repo Wik.Repo

    references do
      reference :group, on_delete: :delete
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

  changes do
    change fn changeset, _ctx ->
             case Ash.Changeset.fetch_change(changeset, :name) do
               {:ok, name} when is_binary(name) ->
                 Ash.Changeset.force_change_attribute(changeset, :name, String.downcase(name))

               _ ->
                 changeset
             end
           end,
           on: [:create, :update]
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      allow_nil? false
      public? true
    end

    has_many :tag_to_tagged_blocks, Wik.Tags.TagToTaggedBlock do
      destination_attribute :tag_id
    end

    has_many :page_to_tags, Wik.Tags.PageToTag do
      destination_attribute :tag_id
    end
  end

  identities do
    identity :unique_group_name, [:group_id, :name]
  end
end
