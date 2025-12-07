defmodule Wik.Wiki.Backlink.CascadeTest do
  use Wik.DataCase, async: true
  import Wik.Generator

  alias Wik.Wiki.Backlink
  alias Wik.Wiki.Page

  test "deleting group cascades backlinks" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    _target = create_page(group, user, "Target")
    _source = create_page(group, user, "Source", "See [[Target]]")

    assert backlink_count() == 1

    Ash.destroy!(group, actor: user)

    assert backlink_count() == 0
  end

  test "deleting source page cascades backlinks" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    target = create_page(group, user, "Target")
    source = create_page(group, user, "Source", "See [[Target]]")

    assert backlink_count() == 1

    Ash.destroy!(source, actor: user)

    assert backlink_count() == 0
    assert {:ok, _} = Ash.get(Page, target.id, actor: user)
  end

  test "deleting target page cascades backlinks" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    target = create_page(group, user, "Target")
    _source = create_page(group, user, "Source", "See [[Target]]")

    assert backlink_count() == 1

    Ash.destroy!(target, actor: user)

    assert backlink_count() == 0
  end

  defp create_page(group, actor, title, text \\ nil) do
    Page
    |> Ash.Changeset.for_create(
      :create,
      %{title: title, text: text},
      actor: actor,
      context: %{shared: %{current_group_id: group.id}}
    )
    |> Ash.create!()
  end

  defp backlink_count do
    Backlink |> Ash.read!(authorize?: false) |> Enum.count()
  end
end
