defmodule Wik.Groups.Group do
  @moduledoc """
  Schema and changeset functions for groups.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "groups" do
    field :name, :string
    field :slug, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:id, :slug, :name])
    |> unique_constraint(:slug)
    |> validate_required([:id, :slug, :name])
  end
end
