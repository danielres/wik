defmodule Wik.Page do
  use Memoize
  alias Wik.Utils

  def pages_dir(group_slug), do: Path.join(Path.join("data", group_slug), "wiki")

  def file_path(group_slug, slug),
    do: Path.join(pages_dir(group_slug), "#{slug}.md")

  def load(group_slug, slug) do
    path = file_path(group_slug, slug)

    if File.exists?(path) do
      document = FrontMatter.parse(File.read!(path))
      {:ok, document}
    else
      :not_found
    end
  end

  def save(group_slug, slug, body, metadata \\ %{}) do
    File.mkdir_p!(pages_dir(group_slug))
    document = FrontMatter.assemble(metadata, body)
    File.write!(file_path(group_slug, slug), document)
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
