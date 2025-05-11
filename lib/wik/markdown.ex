defmodule Wik.Markdown do
  @moduledoc """
  A module for parsing markdown using Earmark,
  specifically transforming wiki links like [[Some Link]]
  into HTML <a> tags with a specified base path.
  """

  alias Earmark.Parser
  alias Earmark.Transform
  alias Wik.Utils

  def sanitize(markdown) do
    sanitized =
      markdown
      |> HtmlSanitizeEx.markdown_html()
      |> preserve_html_entities()

    sanitized
  end

  defp preserve_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  @doc """
  Parses the given `markdown` string using Earmark,
  converting wiki links like [[Some Link]] into <a> tags.
  `base_path` is prepended to the encoded link text.
  For example, if `base_path` is "/wiki/", then [[Some Link]]
  becomes <a href="/wiki/some-link">Some Link</a>.
  """

  def parse(markdown, base_path) do
    case Parser.as_ast(markdown, wikilinks: true) do
      {:ok, ast, _messages} ->
        transformed_ast = Transform.map_ast(List.wrap(ast), &transform_node(&1, base_path))
        Enum.map_join(transformed_ast, "", &Transform.transform/1)

      _ ->
        {:error, "Unexpected return value from Parser.as_ast/2"}
    end
  end

  defp transform_node({"a", [{"href", href}], children, meta} = node, base_path) do
    if Utils.Href.external?(href) do
      node
    else
      slug = href |> Utils.slugify()
      {"a", [{"href", Path.join(base_path, slug)}], children, meta}
    end
  end

  defp transform_node({"a", _attrs, _children, _meta} = node, _base_path), do: node

  defp transform_node({"img", attrs, children, meta}, _base_path) do
    src = attrs |> Enum.find(fn {key, _} -> key == "src" end) |> elem(1)

    if Utils.Youtube.is_youtube_url?(src) do
      video_id = Utils.Youtube.extract_youtube_id(src)
      playlist_id = Utils.Youtube.extract_playlist_id(src)
      embed_url = Utils.Youtube.build_embed_url(video_id, playlist_id)

      youtube_type_class =
        if playlist_id, do: "embed-youtube-playlist", else: "embed-youtube-video"

      {"iframe",
       [
         {"class", "embed embed-youtube #{youtube_type_class}"},
         {"src", embed_url},
         {"width", "560"},
         {"height", "315"},
         {"frameborder", "0"},
         {"allowfullscreen", "true"}
       ], [], meta}
    else
      {"img", attrs, children, meta}
    end
  end

  defp transform_node(other, _base_path), do: other
end
