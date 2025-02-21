defmodule Wik.Page do
  @moduledoc """
  This module provides functions for handling wiki pages, including loading,
  saving, and constructing file paths for the pages.
  """

  use Memoize
  alias Wik.Utils
  alias Wik.Revisions
  alias Wik.Revisions.Patch

  def pages_dir(group_slug), do: Path.join(Path.join("data", group_slug), "wiki")

  def file_path(group_slug, slug),
    do: Path.join(pages_dir(group_slug), "#{slug}.md")

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
    File.mkdir_p!(pages_dir(group_slug))
    previous_document = load_raw(group_slug, slug)
    new_document = FrontMatter.assemble(metadata, body)
    File.write!(file_path(group_slug, slug), new_document)
    Wik.Revisions.append(user_id, resource_path, previous_document, new_document)
  end

  defmemo backlinks(group_slug, current_page_slug), expires_in: 15 * 1000 do
    pages_dir(group_slug)
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
    files = File.ls!(pages_dir(group_slug))

    root_names = files |> Enum.map(&Path.rootname/1)

    filtered =
      root_names
      |> Enum.filter(fn page ->
        String.contains?(String.downcase(page), String.downcase(term))
      end)

    Enum.sort(filtered)
  end
end
