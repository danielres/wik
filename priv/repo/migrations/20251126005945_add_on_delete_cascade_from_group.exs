defmodule Wik.Repo.Migrations.AddOnDeleteCascadeFromGroup do
  use Ecto.Migration

  def change do
    drop constraint(:pages, :pages_group_id_fkey)
    drop constraint(:group_user_relations, :group_user_relations_group_id_fkey)

    alter table(:pages) do
      modify :group_id, references(:groups, on_delete: :delete_all, type: :uuid)
    end

    alter table(:group_user_relations) do
      modify :group_id, references(:groups, on_delete: :delete_all, type: :uuid)
    end
  end
end
