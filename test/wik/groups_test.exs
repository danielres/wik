defmodule Wik.GroupsTest do
  use Wik.DataCase

  alias Wik.Groups

  describe "groups" do
    alias Wik.Groups.Group

    import Wik.GroupsFixtures

    @invalid_attrs %{id: nil, name: nil, slug: nil}

    test "list_groups/0 returns all groups" do
      group = group_fixture()
      assert Groups.list_groups() == [group]
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Groups.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      valid_attrs = %{id: "some id", name: "some name", slug: "some slug"}

      assert {:ok, %Group{} = group} = Groups.create_group(valid_attrs)
      assert group.id == "some id"
      assert group.name == "some name"
      assert group.slug == "some-slug"
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Groups.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()

      update_attrs = %{
        id: "some updated id",
        name: "some updated name",
        slug: "some-updated-slug"
      }

      assert {:ok, %Group{} = group} = Groups.update_group(group, update_attrs)
      assert group.id == "some updated id"
      assert group.name == "some updated name"
      assert group.slug == "some-updated-slug"
    end

    test "update_group/2 with invalid data returns error changeset" do
      group = group_fixture()
      assert {:error, %Ecto.Changeset{}} = Groups.update_group(group, @invalid_attrs)
      assert group == Groups.get_group!(group.id)
    end

    test "delete_group/1 deletes the group" do
      group = group_fixture()
      assert {:ok, %Group{}} = Groups.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Groups.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset" do
      group = group_fixture()
      assert %Ecto.Changeset{} = Groups.change_group(group)
    end
  end
end
