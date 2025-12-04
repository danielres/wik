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

  test "parse_slugs extracts wikilinks and relative links scoped to group" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    markdown = """
    Intro [[Alpha Page]]
    See [beta](/#{group.slug}/wiki/Beta-Note)
    Ignore [other](/other/wiki/Skip)
    """

    slugs = Utils.parse_slugs(markdown, group.slug) |> MapSet.to_list() |> Enum.sort()
    assert slugs == ["Alpha page", "Beta-note"]
  end

  test "creating page with link records backlink to existing target" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    target = create_page(group, user, "Target Page", "Content")
    _source = create_page(group, user, "Source", "See [[#{target.slug}]] for details")

    backlinks = Utils.list_for_page(target)
    assert length(backlinks) == 1
    assert hd(backlinks).source_page_id != target.id
    assert hd(backlinks).target_page_id == target.id
    assert hd(backlinks).target_slug == target.slug
  end

  test "backlinks to missing slug are promoted when page is created" do
    user = generate(user(authorize?: false))
    group = generate(group(actor: user, authorize?: false))

    missing_slug = "Missing Page"
    source = create_page(group, user, "Source", "Link to [[#{missing_slug}]]")

    # Backlink exists but with nil target_page_id
    backlinks_for_missing_slug =
      Utils.list_for_page(%Wik.Wiki.Page{
        id: Ecto.UUID.generate(),
        slug: missing_slug,
        group_id: group.id
      })

    assert length(backlinks_for_missing_slug) == 1
    assert hd(backlinks_for_missing_slug).target_page_id == nil
    assert hd(backlinks_for_missing_slug).source_page_id == source.id

    missing = create_page(group, user, missing_slug, "# #{missing_slug}")

    promoted = Utils.list_for_page(missing)
    assert length(promoted) == 1
    assert hd(promoted).target_page_id == missing.id
    assert hd(promoted).source_page_id == source.id
  end
end
