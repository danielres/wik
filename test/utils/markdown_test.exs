defmodule Utils.MarkdownTest do
  use ExUnit.Case, async: true

  alias Utils.Markdown

  test "slugify mirrors milkdown anchor style" do
    assert Markdown.generate_milkdown_slug("Some links #links") == "some-links-#links"
    assert Markdown.generate_milkdown_slug("Été #été") == "été-#été"
    assert Markdown.generate_milkdown_slug("Foo! #Bar?") == "foo-#bar"
    assert Markdown.generate_milkdown_slug("   ") == "section"
  end

  test "dedupe_slug appends #-style suffix" do
    {frag1, counts} = Markdown.dedupe_slug("foo", %{})
    {frag2, counts} = Markdown.dedupe_slug("foo", counts)
    {frag3, _} = Markdown.dedupe_slug("foo", counts)
    assert frag1 == "foo"
    assert frag2 == "foo-#2"
    assert frag3 == "foo-#3"
  end

  test "scan_tags and strip_tags" do
    title = "Title #One #two"
    assert Markdown.extract_tags(title) == ["#one", "#two"]
    assert Markdown.strip_tags(title) |> String.trim() == "Title"
  end

  test "find_block_end picks next same-or-higher header or end" do
    lines = ["# A", "## B", "### C", "## D", "# E"]
    toc = Markdown.extract_toc(lines)

    # header 1 (## B) ends before next same-or-higher (## D at line 3)
    b_idx = Enum.find_index(toc, &(&1.title == "B"))
    assert Markdown.find_block_end(toc, b_idx, 2, length(lines) - 1) == 2

    # last header ends at end of document
    e_idx = Enum.find_index(toc, &(&1.title == "E"))
    assert Markdown.find_block_end(toc, e_idx, 1, length(lines) - 1) == length(lines) - 1
  end

  test "extract_toc captures levels, tags, slugs, and line indexes" do
    lines = [
      "# Title #Main",
      "## Child #One #Two",
      "### NoTag",
      "Paragraph"
    ]

    toc = Markdown.extract_toc(lines)
    assert length(toc) == 3

    [
      %{level: 1, title: "Title", slug: "title-#main", tags: ["#main"], line_index: 0},
      %{level: 2, title: "Child", slug: "child-#one-#two", tags: ["#one", "#two"], line_index: 1},
      %{level: 3, title: "NoTag", slug: "notag", tags: [], line_index: 2}
    ] = toc
  end

  test "collect_tagged_blocks normalizes headings and dedupes fragments" do
    text = """
    # Hobbies

    ## Cooking #hobby

    Some text

    - one
    - two

    ### Pasta Night #hobby

    Let's have a pasta night!


    ### Pasta Night #hobby

    Let's have another pasta night!
    """

    blocks = Markdown.extract_tagged_blocks(text, "hobby", headings_base_level: 1)

    assert length(blocks) == 3

    assert [
             %{
               header_titles_stack: ["Hobbies", "Cooking"],
               slug_stack: ["hobbies", "cooking-#hobby"]
             }
             | _
           ] = blocks

    first_block = hd(blocks)
    assert String.starts_with?(first_block.markdown, "# Cooking #hobby")

    Enum.each(blocks, fn block ->
      assert Enum.any?(block.slug_stack, fn slug -> String.contains?(slug, "hobby") end)
    end)

    # Second and third blocks carry their respective body text
    assert Enum.at(blocks, 1).markdown |> String.contains?("Let's have a pasta night!")
    assert Enum.at(blocks, 2).markdown |> String.contains?("Let's have another pasta night!")

    last_block = List.last(blocks)
    assert last_block.header_titles_stack == ["Hobbies", "Cooking", "Pasta Night"]
    assert last_block.slug_stack |> List.last() == "pasta-night-#hobby-#2"
    assert String.starts_with?(last_block.markdown, "# Pasta Night #hobby")
  end
end
