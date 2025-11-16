defmodule Wik.Accounts.GroupTest do
  use ExUnit.Case, async: true

  use Wik.DataCase, async: true

  test "creates group with actor as author and member" do
    user = create_user!()
    group = user |> create_group!(authorize?: false)

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
    user1 = create_user!()
    user2 = create_user!()
    group = create_group!(user1)

    # User1 (member) can read
    assert {:ok, _} = Wik.Accounts.Group |> Ash.get(group.id, actor: user1)

    # User2 (non-member) cannot read
    {:error, error} = Wik.Accounts.Group |> Ash.get(group.id, actor: user2)
    assert %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]} = error
  end

  test "destroying group removes memberships but not users" do
    user = create_user!()

    group = user |> create_group!(authorize?: false)

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

  test "can add and remove members" do
    # TODO: ensure that only a group author can add/remove members
    user1 = create_user!()
    user2 = create_user!()

    group = create_group!(user1)

    # Add user2 as member - include BOTH users
    group =
      group
      |> Ash.Changeset.for_update(:update, %{}, actor: user1)
      # Include both!
      |> Ash.Changeset.manage_relationship(:users, [user1, user2],
        type: :append_and_remove,
        authorize?: false
      )
      |> Ash.update!()
      |> Ash.load!(:users, authorize?: false)

    assert length(group.users) == 2

    # Remove user2 - keep only user1
    group =
      group
      |> Ash.Changeset.for_update(:update, %{}, actor: user1)
      # Only user1 now
      |> Ash.Changeset.manage_relationship(:users, [user1],
        type: :append_and_remove,
        authorize?: false
      )
      |> Ash.update!()
      |> Ash.load!(:users, authorize?: false)

    assert length(group.users) == 1
    assert hd(group.users).id == user1.id
  end

  defp create_user! do
    Wik.Accounts.User
    |> Ash.Changeset.for_create(:create, %{
      email: "user#{System.unique_integer()}@example.com"
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_group!(user, opts \\ [], attrs \\ %{}) do
    default_attrs = %{
      title: "Test Group #{System.unique_integer()}",
      text: "Test description"
    }

    attrs = Map.merge(default_attrs, attrs)

    default_opts = [
      authorize?: true
    ]

    opts = Keyword.merge(default_opts, opts)

    Wik.Accounts.Group
    |> Ash.Changeset.for_create(
      :create,
      # Use merged attrs, not default_attrs  
      attrs,
      # Merge actor with opts  
      Keyword.merge([actor: user], opts)
    )
    |> Ash.create!()
  end
end
