defmodule Wik.Wiki do
  alias Wik.Utils
  # Replace occurrences of [[Link Text]] with a link to /pages/the-slug
  def render(group_slug, content) do
    content
    |> replace_links(group_slug)
    |> Earmark.as_html!(escape: false)
  end

  defp replace_links(content, group_slug) do
    Regex.replace(~r/\[\[([^\]]+)\]\]/, content, fn _full, link_text ->
      slug = Utils.slugify(link_text)
      ~s([#{link_text}]\(/#{group_slug}/wiki/#{slug}\))
    end)
  end
end
