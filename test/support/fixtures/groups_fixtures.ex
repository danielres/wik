defmodule Wik.GroupsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Wik.Groups` context.
  """

  @doc """
  Generate a group.
  """

  def group_fixture(attrs \\ %{}) do
    {:ok, group} =
      attrs
      |> Enum.into(%{
        id: "testgroup_id",
        name: "Test Group",
        slug: "test-group",
        owner: "_"
      })
      |> Wik.Groups.create_group()

    group
  end
end
