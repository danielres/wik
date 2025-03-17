defmodule Wik.UsersTest do
  use Wik.DataCase

  alias Wik.Users

  describe "users" do
    alias Wik.Users.User

    import Wik.UsersFixtures

    @invalid_attrs %{
      id: nil,
      telegram_id: nil,
      first_name: nil,
      last_name: nil,
      photo_url: nil
    }

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Users.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Users.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        telegram_id: "some telegram_id",
        username: "some username",
        first_name: "some firstname",
        last_name: "some lastname",
        photo_url: "some photo_url"
      }

      assert {:ok, %User{} = user} = Users.create_user(valid_attrs)
      assert user.telegram_id == "some telegram_id"
      assert user.username == "some username"
      assert user.first_name == "some firstname"
      assert user.last_name == "some lastname"
      assert user.photo_url == "some photo_url"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        telegram_id: "some updated telegram_id",
        username: "some updated username",
        first_name: "some updated first_name",
        last_name: "some updated last_name",
        photo_url: "some updated photo_url"
      }

      assert {:ok, %User{} = user} = Users.update_user(user, update_attrs)
      assert user.telegram_id == "some updated telegram_id"
      assert user.username == "some updated username"
      assert user.first_name == "some updated first_name"
      assert user.last_name == "some updated last_name"
      assert user.photo_url == "some updated photo_url"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_user(user, @invalid_attrs)
      assert user == Users.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Users.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Users.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Users.change_user(user)
    end
  end
end
