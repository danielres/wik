defmodule Wik.Revisions.Revision do
  @moduledoc """
  This module defines the Revision schema and implements changeset functions
  for validating and casting revision data in the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "revisions" do
    field :resource_path, :string
    field :user_id, :string
    field :patch, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [:resource_path, :user_id, :patch])
    |> validate_required([:resource_path, :user_id, :patch])
  end
end
