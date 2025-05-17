defmodule Wik.Markdown.Embeds.PageTest do
  use ExUnit.Case, async: true
  alias Wik.Markdown.Embeds.Page, as: PageEmbeds
  alias Wik.Markdown
  alias Wik.Page

  @group_slug "TEST_GROUP"
  @base_path "TEST_GROUP/wiki"

  @markdown """
  # Main Title

  ## Section One

  Content of section one.

  ## Section Two

  Content of section two.
  More content in section two.

  ### Subsection Two.A

  Content of subsection two A.

  # Another Main Title

  ## Section Three

  Content of section three.
  """

  describe "embed/5" do
    test "embeds a page with no recursion" do
      page_slug = "page-embed-1"
      markdown = Page.load(@group_slug, page_slug)
      ast = Markdown.to_ast(markdown, @base_path, [page_slug])
      assert [{"div", _, [_, [{"p", _, ["page-embed-11 content"], %{}}]], _}] = ast
    end

    test "prevents recursive embedding infinite loop" do
      page_slug = "page-embed-2"
      markdown = Page.load(@group_slug, page_slug)
      ast = Markdown.to_ast(markdown, @base_path, [page_slug])

      assert [
               {"div", [{"class", "embed embed-page embed-page-allowed"}],
                [_, [_, {"div", [{"class", "embed embed-page embed-page-blocked"}], _, _}]], _}
             ] = ast
    end
  end

  describe "apply_offset_replacement/2" do
    test "handles offset correctly" do
      markdown = """
      # Title

      ## Subtitle
      """

      actual = PageEmbeds.apply_offset_replacement(markdown, 2)

      expected = """
      ### Title

      #### Subtitle
      """

      assert actual == expected
    end

    test "handles invalid offset gracefully" do
      markdown = """
      # Title

      ## Subtitle
      """

      expected = """
      ## Title

      ### Subtitle
      """

      actual = PageEmbeds.apply_offset_replacement(markdown, -1)

      assert actual == expected
    end
  end

  describe "apply_page_head_removal/2" do
    test "removes the first heading when head? is false" do
      markdown = "# Heading\nContent"
      head? = false
      assert PageEmbeds.apply_page_head_removal(markdown, head?) == "\nContent"
    end

    test "keeps the heading when head? is true" do
      markdown = "# Heading\nContent"
      head? = true
      assert PageEmbeds.apply_page_head_removal(markdown, head?) == "# Heading\nContent"
    end
  end

  describe "extract_section/2" do
    test "returns entire markdown if section is nil" do
      assert PageEmbeds.extract_section(@markdown, nil) == @markdown
    end

    test "returns entire markdown if section not found" do
      assert PageEmbeds.extract_section(@markdown, "Nonexistent Section") == @markdown
    end

    test "extracts specific section" do
      result = PageEmbeds.extract_section(@markdown, "Section Two")

      expected = """
      ## Section Two

      Content of section two.
      More content in section two.

      ### Subsection Two.A

      Content of subsection two A.
      """

      assert result == expected
    end
  end

  describe "find_header/2" do
    test "returns the header line if found" do
      assert PageEmbeds.find_header(@markdown, "Section One") == "## Section One"
    end

    test "is case-insensitive when finding headers" do
      assert PageEmbeds.find_header(@markdown, "section two") == "## Section Two"
    end

    test "supports substrigs" do
      assert PageEmbeds.find_header(@markdown, "two") == "## Section Two"
    end

    test "returns nil if header is not found" do
      assert PageEmbeds.find_header(@markdown, "Nonexistent Header") == nil
    end
  end

  describe "get_header_text/2" do
    test "extracts header text without hashes" do
      assert PageEmbeds.get_header_text(@markdown, "Section Two") == "Section Two"
    end

    test "returns nil if header is not found" do
      assert PageEmbeds.get_header_text(@markdown, "Nonexistent Header") == nil
    end

    test "works with case-insensitive headers" do
      assert PageEmbeds.get_header_text(@markdown, "section one") == "Section One"
    end

    test "supports substrigs" do
      assert PageEmbeds.get_header_text(@markdown, "one") == "Section One"
    end
  end
end
