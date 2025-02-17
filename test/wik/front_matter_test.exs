defmodule FrontMatterTest do
  use ExUnit.Case
  alias FrontMatter

  @valid_document """
  ---
  author: Test Author
  title: Test Title
  ---
  This is the body of the document.
  """

  @invalid_document """
  This is the body of the document without front matter.
  """

  test "parse/1 with valid front matter" do
    {metadata, body} = FrontMatter.parse(@valid_document)
    #
    assert metadata == %{"title" => "Test Title", "author" => "Test Author"}
    assert body == "This is the body of the document.\n"
  end

  test "parse/1 with invalid front matter" do
    {metadata, body} = FrontMatter.parse(@invalid_document)
    assert metadata == %{}
    assert body == @invalid_document
  end

  test "parse/1 with list input" do
    {metadata, body} = FrontMatter.parse(String.to_charlist(@valid_document))
    assert metadata == %{"title" => "Test Title", "author" => "Test Author"}
    assert body == "This is the body of the document.\n"
  end

  test "assemble/2 reassembles content correctly" do
    metadata = %{"title" => "Test Title", "author" => "Test Author"}
    body = "This is the body of the document.\n"
    assembled_content = FrontMatter.assemble(metadata, body)
    assert assembled_content == @valid_document
  end
end
