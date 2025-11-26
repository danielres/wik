defmodule Wik.Accounts.GroupTest do
  use Wik.DataCase, async: true
  import Wik.Generator

  test "creates group with actor as author and member" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    assert group.author_id == user.id

    # Verify user is in the many-to-many relationship
    group = Ash.load!(group, :users, authorize?: false)
    assert Enum.any?(group.users, &(&1.id == user.id))
  end

  test "cannot create group without actor" do
    assert {:error, changeset} =
             Wik.Accounts.Group
             |> Ash.Changeset.for_create(
               :create,
               %{title: "Test Group", text: "Description"},
               actor: nil
             )
             |> Ash.create()

    assert changeset.errors |> Enum.count() > 0
  end

  test "only members can read group" do
    user1 = generate(user(authorize?: false))
    user2 = generate(user(authorize?: false))
    group = generate(group(actor: user1))

    # User1 (member) can read
    assert {:ok, _} = Wik.Accounts.Group |> Ash.get(group.id, actor: user1)

    # User2 (non-member) cannot read
    {:error, error} = Wik.Accounts.Group |> Ash.get(group.id, actor: user2)
    assert %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]} = error
  end

  test "destroying group removes memberships but not users" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize: false))

    # Verify membership exists
    memberships = Ash.read!(Wik.Accounts.GroupUserRelation)
    assert Enum.any?(memberships, &(&1.group_id == group.id))

    # Destroy group
    Ash.destroy!(group, actor: user)

    # Verify membership is gone
    memberships = Ash.read!(Wik.Accounts.GroupUserRelation)
    refute Enum.any?(memberships, &(&1.group_id == group.id))

    # Verify user still exists
    assert Ash.get!(Wik.Accounts.User, user.id, authorize?: false)
  end

  test "destroying group removes pages" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    page =
      Wik.Wiki.Page
      |> Ash.Changeset.for_create(
        :create,
        %{title: "Page"},
        actor: user,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.create!()

    # Ensure page exists before deletion
    assert Ash.get!(Wik.Wiki.Page, page.id, actor: user)

    Ash.destroy!(group, actor: user)

    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
             Ash.get(Wik.Wiki.Page, page.id, actor: user)
  end

  test "only author can add and remove members" do
    user1 = generate(user(authorize?: false))
    user2 = generate(user(authorize?: false))
    user3 = generate(user(authorize?: false))
    group = generate(group(actor: user1))

    # user1 (author) can add user2 as member 
    group =
      group
      |> Ash.Changeset.for_update(:update, %{}, actor: user1)
      |> Ash.Changeset.manage_relationship(:users, [user2],
        type: :append,
        # Still needed for the relationship management itself
        authorize?: false
      )
      # But authorize the update action
      |> Ash.update!(authorize?: true)
      |> Ash.load!(:users, authorize?: false)

    assert length(group.users) == 2

    # user2 (non-author) CANNOT add user3 as member
    assert_raise Ash.Error.Forbidden, fn ->
      group
      |> Ash.Changeset.for_update(:update, %{}, actor: user2)
      |> Ash.Changeset.manage_relationship(:users, [user3],
        type: :append,
        authorize?: false
      )
      |> Ash.update!(authorize?: true)
    end

    # user1 (author) can remove user2 - keep only user1
    group =
      group
      |> Ash.Changeset.for_update(:update, %{}, actor: user1)
      |> Ash.Changeset.manage_relationship(:users, [user2],
        type: :remove,
        authorize?: false
      )
      |> Ash.update!(authorize?: true)
      |> Ash.load!(:users, authorize?: false)

    assert length(group.users) == 1
    assert hd(group.users).id == user1.id
  end
end
