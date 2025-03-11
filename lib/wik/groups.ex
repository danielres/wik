defmodule Wik.Groups do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Wik.Repo

  alias Wik.Groups.Group

  def list_groups do
    Repo.all(Group)
  end

  def get_group!(id), do: Repo.get!(Group, id)

  def find_group_by_slug(slug) do
    Repo.one(from g in Group, where: g.slug == ^slug)
  end

  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  def get_group_name(group_slug) do
    group = find_group_by_slug(group_slug)
    group.name
  end
end
