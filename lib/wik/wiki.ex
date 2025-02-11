defmodule Wik.Wiki do
  # Replace occurrences of [[Link Text]] with a link to /pages/the-slug
  def render(group_slug, content) do
    content
    |> replace_links(group_slug)
    |> Earmark.as_html!(escape: false)
  end

  defp replace_links(content, group_slug) do
    Regex.replace(~r/\[\[([^\]]+)\]\]/, content, fn _full, link_text ->
      slug = link_text |> String.downcase() |> String.replace(" ", "-")
      ~s([#{link_text}]\(/#{group_slug}/wiki/#{slug}\))
    end)
  end
end
