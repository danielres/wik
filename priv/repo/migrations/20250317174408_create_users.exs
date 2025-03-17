defmodule Wik.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :telegram_id, :string
      add :username, :string
      add :first_name, :string
      add :last_name, :string
      add :photo_url, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, :telegram_id)
  end
end
