defmodule Wik.Repo.Migrations.AddLastSeenToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_seen, :utc_datetime
    end
  end
end
