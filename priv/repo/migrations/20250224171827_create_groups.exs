defmodule Wik.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :string, primary_key: true
      add :slug, :string
      add :name, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:groups, [:slug])
  end
end
