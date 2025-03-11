defmodule Wik.UserTest do
  use Wik.DataCase, async: true
  alias Wik.User
  alias Wik.Groups.Group
  alias Wik.Repo

  describe "get_or_create_from_telegram/2" do
    setup do
      group1 =
        %Group{id: "group1", name: "Group One", slug: "group-one"}
        |> Group.changeset(%{})
        |> Repo.insert!()

      group2 =
        %Group{id: "group2", name: "Group Two", slug: "group-two"}
        |> Group.changeset(%{})
        |> Repo.insert!()

      %{group1: group1, group2: group2}
    end

    test "returns user data with groups they are a member of", %{group1: group1, group2: group2} do
      telegram_params = %{
        "id" => "123456",
        "first_name" => "John",
        "last_name" => "Doe",
        "auth_date" => "1615123456",
        "username" => "johndoe",
        "photo_url" => "https://example.com/photo.jpg"
      }

      # Inject a custom membership checker.
      # Assume the user is a member of group1 but not group2:
      membership_checker = fn
        %Group{id: "group1"}, _user_id, _bot_token -> true
        %Group{id: "group2"}, _user_id, _bot_token -> false
        _group, _user_id, _bot_token -> false
      end

      user =
        User.get_or_create_from_telegram(telegram_params, "test_token",
          membership_checker: membership_checker
        )

      assert user.id == "123456"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.auth_date == "1615123456"
      assert user.username == "johndoe"
      assert user.photo_url == "https://example.com/photo.jpg"

      # The member_of list should only include group1.
      assert length(user.member_of) == 1
      [member_group] = user.member_of
      assert member_group.id == group1.id
      assert member_group.name == group1.name
      assert member_group.slug == group1.slug
    end
  end
end
