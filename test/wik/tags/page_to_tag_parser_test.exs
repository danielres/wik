defmodule Wik.Tags.PageToTag.ParserTest do
  use ExUnit.Case, async: true

  alias Wik.Tags.PageToTag.Parser

  test "extracts tags from ATX headers and downcases" do
    text = """
    # Title #Recipe #Italian
    ## Subheading #Quick
    Not a header #skip
    """

    tags = Parser.extract_tags(text) |> Enum.sort()

    assert tags == ["italian", "quick", "recipe"]
  end

  test "ignores non-header lines and de-duplicates tags" do
    text = """
    # One #tag
    # Two #tag
    Paragraph #tag
    """

    tags = Parser.extract_tags(text)

    assert tags == ["tag"]
  end
end
