defmodule Wik.Page do
  @pages_dir "pages"

  def file_path(slug), do: Path.join(@pages_dir, "#{slug}.md")

  def load(slug) do
    path = file_path(slug)

    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      :not_found
    end
  end

  def save(slug, content) do
    File.mkdir_p!(@pages_dir)
    File.write!(file_path(slug), content)
  end

  def backlinks(current_slug) do
    @pages_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(&Path.rootname/1)
    |> Enum.filter(fn slug ->
      # Skip the page itself (if desired)
      if slug == current_slug do
        false
      else
        case load(slug) do
          {:ok, content} ->
            regex = ~r/\[\[([^\]]+)\]\]/

            Regex.scan(regex, content)
            |> Enum.any?(fn [_, link_text] ->
              # Normalize the link text as in your Wiki.render/1 function.
              normalized = link_text |> String.downcase() |> String.replace(" ", "-")
              normalized == current_slug
            end)

          :not_found ->
            false
        end
      end
    end)
    |> Enum.sort()
  end
end
