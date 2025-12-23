defmodule Wik.Tags.PageToTagSyncTest do
  use Wik.DataCase, async: true

  import Wik.Generator
  import Ash.Query

  alias Wik.Tags.{PageToTag, Tag}
  alias Wik.Wiki.Page

  setup do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))
    %{group: group, user: user}
  end

  test "creates tags and page_to_tags on page create", %{group: group, user: user} do
    {:ok, page} =
      Page
      |> Ash.Changeset.for_create(:create, %{title: "T", text: "# Title #Recipe #Italian"},
        actor: user,
        tenant: group.id,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.create()

    page_id = page.id

    tags =
      Tag
      |> filter(group_id == ^group.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.name)
      |> Enum.sort()

    assert "italian" in tags
    assert "recipe" in tags

    page_tags =
      PageToTag
      |> filter(group_id == ^group.id and page_id == ^page_id)
      |> Ash.read!(authorize?: false)

    assert Enum.count(page_tags) == 2
  end

  test "replaces page_to_tags on update (removal)", %{group: group, user: user} do
    {:ok, page} =
      Page
      |> Ash.Changeset.for_create(:create, %{title: "T", text: "# Title #test-one #test-two"},
        actor: user,
        tenant: group.id,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.create()

    page_id = page.id

    # Update removing one tag
    {:ok, _} =
      page
      |> Ash.Changeset.for_update(:update, %{text: "# Title #test-two"},
        actor: user,
        tenant: group.id,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.update()

    page_tags =
      PageToTag
      |> filter(group_id == ^group.id and page_id == ^page_id)
      |> Ash.read!(authorize?: false)

    assert Enum.map(page_tags, & &1.tag_id) |> length() == 1

    tags =
      Tag
      |> filter(group_id == ^group.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.name)
      |> Enum.sort()

    # We keep tag records even if a page drops them; only the join is replaced.
    assert "test-one" in tags
    assert "test-two" in tags
  end

  test "adds page_to_tags on update (addition)", %{group: group, user: user} do
    {:ok, page} =
      Page
      |> Ash.Changeset.for_create(:create, %{title: "T", text: "# Title #one"},
        actor: user,
        tenant: group.id,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.create()

    page_id = page.id

    {:ok, _} =
      page
      |> Ash.Changeset.for_update(:update, %{text: "# Title #test-one #test-two"},
        actor: user,
        tenant: group.id,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.update()

    page_tags =
      PageToTag
      |> filter(group_id == ^group.id and page_id == ^page_id)
      |> Ash.read!(authorize?: false)

    assert Enum.count(page_tags) == 2

    tag_names =
      Tag
      |> filter(group_id == ^group.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.name)
      |> Enum.sort()

    assert "test-one" in tag_names
    assert "test-two" in tag_names
  end

  test "cascades when page deleted", %{group: group, user: user} do
    {:ok, page} =
      Page
      |> Ash.Changeset.for_create(:create, %{title: "T", text: "# Title #x"},
        actor: user,
        tenant: group.id,
        context: %{shared: %{current_group_id: group.id}}
      )
      |> Ash.create()

    page_id = page.id

    page
    |> Ash.Changeset.for_destroy(:destroy, %{},
      actor: user,
      tenant: group.id,
      context: %{shared: %{current_group_id: group.id}}
    )
    |> Ash.destroy!()

    count =
      PageToTag
      |> filter(group_id == ^group.id and page_id == ^page_id)
      |> Ash.count!()

    assert count == 0
  end
end
