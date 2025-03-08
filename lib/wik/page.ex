defmodule Wik.Page do
  @moduledoc """
  This module provides functions for handling wiki pages, including loading,
  saving, and constructing file paths for the pages.
  """

  use Memoize
  alias Wik.Utils
  alias Wik.Revisions.Patch
  alias Wik.Markdown
  alias Wik.Page

  require Logger

  def wiki_dir(group_slug) do
    # TODO: move this to application config
    files_dir = System.fetch_env!("FILE_STORAGE_PATH")
    group_dir = files_dir |> Path.join("groups") |> Path.join(group_slug)
    wiki_dir = group_dir |> Path.join("wiki")

    # TODO: move this to application start
    if !File.exists?(wiki_dir) do
      Logger.info("Creating #{wiki_dir}")
      File.mkdir_p!(wiki_dir)
    end

    wiki_dir
  end

  def file_path(group_slug, slug) do
    wiki_dir(group_slug) |> Path.join("#{slug}.md")
  end

  def resource_path(group_slug, slug), do: "#{group_slug}/wiki/#{slug}"

  def load(group_slug, slug) do
    path = file_path(group_slug, slug)
    if File.exists?(path), do: File.read!(path), else: ""
  end

  def load_rendered(group_slug, page_slug) do
    body = load(group_slug, page_slug)
    render(group_slug, body)
  end

  def load_raw(group_slug, slug) do
    path = file_path(group_slug, slug)

    if File.exists?(path) do
      File.read!(path)
    else
      ""
    end
  end

  def render(group_slug, content) do
    base_path = "/#{group_slug}/wiki/"
    content |> Markdown.parse(base_path)
  end

  def load_at(group_slug, page_slug, index) do
    if index > 0 do
      patched =
        Patch.take(group_slug, page_slug, index)
        |> Patch.apply("")

      {:ok, patched}
    else
      {:ok, ""}
    end
  end

  # TODO: rename to create_or_update
  def upsert(user_id, group_slug, slug, body) do
    body = HtmlSanitizeEx.markdown_html(body)
    resource_path = Page.resource_path(group_slug, slug)
    before = Page.load_raw(group_slug, slug)
    new = body
    File.write!(Page.file_path(group_slug, slug), new)
    {:ok, %{patch: patch}} = Wik.Revisions.append(user_id, resource_path, before, new)
    {:ok, %{before: before, after: new, patch: Patch.from_json(patch)}}
  end

  defmemo backlinks(group_slug, current_page_slug), expires_in: :timer.seconds(15) do
    wiki_dir(group_slug)
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(fn filename ->
      rootname = Path.rootname(filename)
      # Skip the current page
      if rootname == current_page_slug do
        nil
      else
        body = load(group_slug, rootname)
        wikilink_regex = ~r/\[\[([^\]]+)\]\]/

        if Regex.scan(wikilink_regex, body)
           |> Enum.any?(fn [_, link_text] ->
             Utils.slugify(link_text) == current_page_slug
           end) do
          rootname
        else
          nil
        end
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defmemo suggestions(group_slug, term), expires_in: 15 * 1000 do
    files = File.ls!(wiki_dir(group_slug))

    root_names = files |> Enum.map(&Path.rootname/1)

    filtered =
      root_names
      |> Enum.filter(fn page ->
        String.contains?(String.downcase(page), String.downcase(term))
      end)

    Enum.sort(filtered)
  end
end
