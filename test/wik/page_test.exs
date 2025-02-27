defmodule Wik.PageTest do
  @moduledoc """
  Test cases for Wik.Page module.
  """
  use ExUnit.Case, async: false
  alias Wik.Page
  alias FrontMatter

  @group "testgroup"
  @slug "testpage"
  @metadata %{"title" => "Test Page"}
  @body "Hello, this is a test. [[Link]]"
  @document FrontMatter.assemble(@metadata, @body)

  setup_all do
    # Set FILE_STORAGE_PATH to a temporary directory for testing.
    System.put_env("FILE_STORAGE_PATH", "tmp_test_data")
    File.rm_rf!("tmp_test_data")
    File.mkdir_p!("tmp_test_data")
    :ok
  end

  setup do
    # Check out the database connection.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Wik.Repo)

    # Create the wiki directory for the group.
    wiki_dir = Path.join(["tmp_test_data", "groups", @group, "wiki"])
    File.mkdir_p!(wiki_dir)
    %{wiki_dir: wiki_dir}
  end

  test "file_path/2 returns the correct file path", %{wiki_dir: wiki_dir} do
    expected = Path.join(wiki_dir, "#{@slug}.md")
    assert Page.file_path(@group, @slug) == expected
  end

  test "save/5 writes the file and load/2 returns the document", %{wiki_dir: _wiki_dir} do
    file_path = Page.file_path(@group, @slug)
    if File.exists?(file_path), do: File.rm!(file_path)

    user_id = "testuser"
    Page.save(user_id, @group, @slug, @body, @metadata)

    assert File.exists?(file_path)

    {:ok, {loaded_metadata, loaded_body}} = Page.load(@group, @slug)
    assert loaded_body =~ "Hello, this is a test."
    assert loaded_metadata["title"] == "Test Page"
  end

  test "load_raw/2 returns the raw document", %{wiki_dir: _} do
    file_path = Page.file_path(@group, @slug)
    File.write!(file_path, @document)
    content = Page.load_raw(@group, @slug)
    assert content == @document
  end

  test "render/2 replaces wiki links with HTML links", %{wiki_dir: _} do
    # Render returns HTML.
    rendered = Page.render(@group, @body)
    # For our input, Earmark produces something like:
    # "<p>\nHello, this is a test. <a href=\"/testgroup/wiki/link\">Link</a></p>\n"
    expected_link = ~s(<a href="/testgroup/wiki/link">Link</a>)
    assert rendered =~ expected_link
  end

  test "suggestions/2 returns matching page names", %{wiki_dir: wiki_dir} do
    File.write!(
      Path.join(wiki_dir, "apple.md"),
      FrontMatter.assemble(%{"title" => "Apple"}, "Apple content")
    )

    File.write!(
      Path.join(wiki_dir, "banana.md"),
      FrontMatter.assemble(%{"title" => "Banana"}, "Banana content")
    )

    File.write!(
      Path.join(wiki_dir, "cherry.md"),
      FrontMatter.assemble(%{"title" => "Cherry"}, "Cherry content")
    )

    suggestions = Page.suggestions(@group, "app")
    assert "apple" in suggestions
    refute "banana" in suggestions
    refute "cherry" in suggestions
  end

  test "backlinks/2 returns pages linking to the current page", %{wiki_dir: wiki_dir} do
    # Create a file that contains a markdown link to the test page.
    link_content = "This page links to [[TestPage]] in a sentence."

    File.write!(
      Path.join(wiki_dir, "other.md"),
      FrontMatter.assemble(%{"title" => "Other"}, link_content)
    )

    backlinks = Page.backlinks(@group, @slug)
    # Expect to find at least one backlink.
    assert backlinks != []
  end
end
