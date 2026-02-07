defmodule Wik.Wiki.BacklinkTest do
  use Wik.DataCase, async: true
  import Wik.Generator
  alias Wik.Wiki.PageTree

  alias Wik.Wiki.Backlink.Utils

  defp create_page(group, actor, title, text) do
    Wik.Wiki.Page
    |> Ash.Changeset.for_create(
      :create,
      %{title: title, text: text},
      actor: actor,
      context: %{shared: %{current_group_id: group.id}}
    )
    |> Ash.create!()
  end

  test "parse_wikilink_ids extracts wikid links" do
    markdown = """
    Intro [Alpha](wikid:019b1111-1111-7111-8111-111111111111)
    See [beta](wikid:019b2222-2222-7222-8222-222222222222)
    """

    ids = Utils.parse_wikilink_ids(markdown) |> MapSet.to_list() |> Enum.sort()

    assert ids == [
             "019b1111-1111-7111-8111-111111111111",
             "019b2222-2222-7222-8222-222222222222"
           ]
  end

  test "creating page with link records backlink to existing target" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    target = create_page(group, user, "Target Page", "Content")

    {:ok, tree, _map} =
      PageTree.Utils.resolve_tree_by_path(target.slug, group.id, user, %{})

    {:ok, ensured_tree} = PageTree.Utils.ensure_page_for_tree(tree, user)

    _source =
      create_page(
        group,
        user,
        "Source",
        "See [link](wikid:#{ensured_tree.id}) for details"
      )

    backlinks = Utils.list_for_page(target)
    assert length(backlinks) == 1
    assert hd(backlinks).source_page_id != target.id
    assert hd(backlinks).target_page_id == target.id
    assert hd(backlinks).target_slug == target.slug
  end

  test "backlinks are recorded for wikid links" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    target = create_page(group, user, "Target Page", "Content")

    {:ok, tree, _map} =
      PageTree.Utils.resolve_tree_by_path(target.slug, group.id, user, %{})

    {:ok, ensured_tree} = PageTree.Utils.ensure_page_for_tree(tree, user)

    source =
      create_page(
        group,
        user,
        "Source",
        "Link to [target](wikid:#{ensured_tree.id})"
      )

    backlinks = Utils.list_for_page(target)
    assert length(backlinks) == 1
    assert hd(backlinks).source_page_id == source.id
    assert hd(backlinks).target_page_id == target.id
  end
end
