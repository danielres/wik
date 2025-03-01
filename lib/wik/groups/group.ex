defmodule Wik.Groups.Group do
  @moduledoc """
  Schema and changeset functions for groups.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Wik.Utils

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "groups" do
    field :name, :string
    field :slug, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:id, :slug, :name])
    |> validate_required([:id, :slug, :name])
    |> update_change(:slug, fn
      slug when is_binary(slug) -> Utils.slugify(slug)
      slug -> slug
    end)
    |> validate_length(:slug, min: 3)
    |> validate_format(:slug, ~r/^[a-z0-9-_]+$/)
    |> unique_constraint(:slug)
  end
end
