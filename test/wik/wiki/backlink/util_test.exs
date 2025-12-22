defmodule Wik.Wiki.BacklinkTest do
  use Wik.DataCase, async: true
  import Wik.Generator

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
    user = generate(user(authorize?: false))

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
    _source = create_page(group, user, "Source", "See [link](wikid:#{target.id}) for details")

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
    source = create_page(group, user, "Source", "Link to [target](wikid:#{target.id})")

    backlinks = Utils.list_for_page(target)
    assert length(backlinks) == 1
    assert hd(backlinks).source_page_id == source.id
    assert hd(backlinks).target_page_id == target.id
  end
end
