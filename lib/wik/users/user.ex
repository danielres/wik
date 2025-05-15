defmodule Wik.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :telegram_id, :string
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :photo_url, :string
    field :last_seen, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :telegram_id,
      :username,
      :first_name,
      :last_name,
      :photo_url,
      :last_seen
    ])
    |> update_change(:telegram_id, &to_string/1)
    |> put_change(:photo_url, Map.get(attrs, :photo_url, ""))
    |> unique_constraint(:telegram_id)
    |> validate_required([
      :telegram_id
    ])
  end
end
