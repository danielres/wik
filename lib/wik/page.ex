defmodule Wik.Page do
  @moduledoc """
  This module provides functions for handling wiki pages, including loading,
  saving, and constructing file paths for the pages.
  """

  use Memoize
  alias Wik.Utils
  alias Wik.Revisions
  alias Wik.Revisions.Patch
  alias Wik.Markdown

  require Logger

  def wiki_dir(group_slug) do
    # TODO: move this to application config
    files_dir = System.get_env("FILE_STORAGE_PATH") || "data"
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

    if File.exists?(path) do
      document = FrontMatter.parse(File.read!(path))
      {:ok, document}
    else
      :not_found
    end
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

  def load_revision(group_slug, slug, revision) do
    resource_path = resource_path(group_slug, slug)
    current_document = load_raw(group_slug, slug)
    taken_revisions = Revisions.take(resource_path, revision)

    {metadata, body} =
      taken_revisions
      |> Enum.map(& &1.patch)
      |> Enum.map(&Patch.from_json/1)
      |> Patch.apply(current_document)
      |> FrontMatter.parse()

    {metadata, body}
  end

  def save(user_id, group_slug, slug, body, metadata \\ %{}) do
    metadata =
      case metadata["created_at"] do
        nil ->
          metadata
          |> Map.put("created_at", DateTime.to_string(DateTime.utc_now()))
          |> Map.put("created_by", user_id)

        _ ->
          metadata
      end
      |> Map.put("updated_at", DateTime.to_string(DateTime.utc_now()))
      |> Map.put("updated_by", user_id)

    body = HtmlSanitizeEx.markdown_html(body)
    resource_path = Wik.Page.resource_path(group_slug, slug)
    previous_document = load_raw(group_slug, slug)
    new_document = FrontMatter.assemble(metadata, body)
    File.write!(file_path(group_slug, slug), new_document)
    Wik.Revisions.append(user_id, resource_path, previous_document, new_document)
  end

  defmemo backlinks(group_slug, current_page_slug), expires_in: 15 * 1000 do
    wiki_dir(group_slug)
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(fn filename ->
      rootname = Path.rootname(filename)
      # Skip the page itself
      if rootname != current_page_slug do
        case load(group_slug, rootname) do
          {:ok, {metadata, body}} ->
            regex = ~r/\[\[([^\]]+)\]\]/

            if Regex.scan(regex, body)
               |> Enum.any?(fn [_, link_text] ->
                 slugified = Utils.slugify(link_text)
                 slugified == current_page_slug
               end) do
              {rootname, metadata}
            else
              nil
            end

          :not_found ->
            nil
        end
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {slug, _metadata} -> slug end)
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
