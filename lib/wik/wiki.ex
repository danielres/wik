defmodule Wik.Wiki do
  # Replace occurrences of [[Link Text]] with a link to /pages/the-slug
  def render(content) do
    content
    |> replace_links()
  end

  defp replace_links(content) do
    Regex.replace(~r/\[\[([^\]]+)\]\]/, content, fn _full, link_text ->
      slug = link_text |> String.downcase() |> String.replace(" ", "-")
      ~s([#{link_text}]\(/pages/#{slug}\))
    end)
  end
end
