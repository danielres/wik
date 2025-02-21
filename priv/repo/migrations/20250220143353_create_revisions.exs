defmodule Wik.Repo.Migrations.CreateRevisions do
  use Ecto.Migration

  def change do
    create table(:revisions) do
      add :resource_path, :string
      add :user_id, :string
      add :patch, :string

      timestamps(type: :utc_datetime)
    end
  end
end
