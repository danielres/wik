defmodule Wik.PageTest do
  @moduledoc """
  Test cases for Wik.Page module.
  """
  use ExUnit.Case, async: false
  alias Wik.Page
  alias FrontMatter

  @group "testgroup"
  @slug "testpage"
  @body "Hello, this is a test. [[Link]]"
  @rendered "<p>\nHello, this is a test. <a href=\"/testgroup/wiki/link\">Link</a></p>\n"
  @document @body

  setup_all do
    test_data_dir = Application.get_env(:wik, :files_storage_path)
    File.rm_rf!(test_data_dir)
    File.mkdir_p!(test_data_dir)
    {:ok, %{test_data_dir: test_data_dir}}
  end

  setup %{test_data_dir: test_data_dir} do
    # Check out the database connection.
    Ecto.Adapters.SQL.Sandbox.checkout(Wik.Repo)
    # Create the wiki directory for the group.
    wiki_dir = Path.join([test_data_dir, "groups", @group, "wiki"])
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
    Page.upsert(user_id, @group, @slug, @body)
    assert File.exists?(file_path)

    body = Page.load(@group, @slug)
    assert body =~ "Hello, this is a test."
  end

  test "load_raw/2 returns the raw document", %{wiki_dir: _} do
    file_path = Page.file_path(@group, @slug)
    File.write!(file_path, @document)
    content = Page.load_raw(@group, @slug)
    assert content == @document
  end

  test "load_rendered/2 returns the rendered document", %{wiki_dir: _} do
    file_path = Page.file_path(@group, @slug)
    File.write!(file_path, @document)
    content = Page.load_rendered(@group, @slug)
    assert content == @rendered
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
    File.write!(Path.join(wiki_dir, "apple.md"), "Apple content")
    File.write!(Path.join(wiki_dir, "banana.md"), "Banana content")
    File.write!(Path.join(wiki_dir, "cherry.md"), "Cherry content")

    suggestions = Page.suggestions(@group, "app")
    assert "apple" in suggestions
    refute "banana" in suggestions
    refute "cherry" in suggestions
  end

  test "backlinks/2 returns pages linking to the current page", %{wiki_dir: wiki_dir} do
    # Create a file that contains a markdown link to the test page.
    link_content = "This page links to [[TestPage]] in a sentence."
    File.write!(Path.join(wiki_dir, "other.md"), link_content)

    backlinks = Page.backlinks(@group, @slug)
    # Expect to find at least one backlink.
    assert backlinks != []
  end

  test "load_at/3 returns the document at the specified revision", %{wiki_dir: _} do
    group_slug = "some_group"
    {:ok, %{after: _v1}} = Page.upsert("testuser", group_slug, @slug, "v1")
    {:ok, %{after: v2}} = Page.upsert("testuser", group_slug, @slug, "v2")
    {:ok, %{after: v3}} = Page.upsert("testuser", group_slug, @slug, "v3")
    latest = Page.load(group_slug, @slug)
    assert latest == v3

    {:ok, loaded_at_0} = Page.load_at(group_slug, @slug, 0)
    assert loaded_at_0 == ""

    res = Page.load_at(group_slug, @slug, 2)
    assert res == {:ok, v2}
  end
end
