defmodule Wik.Markdown do
  @moduledoc """
  A module for parsing Markdown using Earmark,
  transforming wiki links into HTML <a> tags,
  and supporting custom embeds using Markdown image syntax.
  """

  alias Earmark.Parser
  alias Earmark.Transform
  alias Wik.Utils
  alias Wik.Markdown.Embeds

  @doc """
  Sanitizes raw Markdown to safe HTML.
  """
  def sanitize(markdown) do
    markdown
    |> HtmlSanitizeEx.markdown_html()
    |> preserve_html_entities()
  end

  defp preserve_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  def parse(markdown, base_path, embedded_pages) do
    result =
      markdown
      |> Embeds.embed_pages(base_path, embedded_pages)
      |> do_parse(base_path)

    html =
      result
      |> String.replace("EMBED PAGE START", "<div class='embed embed-page'>")
      |> String.replace("EMBED PAGE END", "</div>")

    dbg()
    html
  end

  defp do_parse(markdown, base_path) do
    case Parser.as_ast(markdown, wikilinks: true) do
      {:ok, ast, _msgs} ->
        ast
        |> List.wrap()
        |> Transform.map_ast(&transform_node(&1, base_path), true)
        |> Enum.map_join("", &Transform.transform/1)

      _ ->
        {:error, "Unexpected return from Parser.as_ast/2"}
    end
  end

  defp transform_node({"a", [{"href", href}], children, meta}, base_path) do
    if Utils.Href.external?(href) do
      {"a", [{"href", href}], children, meta}
    else
      slug = Utils.slugify(href)
      {"a", [{"href", Path.join(base_path, slug)}], children, meta}
    end
  end

  defp transform_node({"a", _, _, _} = node, _), do: node

  defp transform_node({"img", attrs, _children, meta}, _base_path) do
    attr_map = Enum.into(attrs, %{})
    src = Map.get(attr_map, "src", "")
    raw_opts = Map.get(attr_map, "alt", "")

    cond do
      Utils.Youtube.is_youtube_url?(src) ->
        Embeds.embed_youtube(meta, raw_opts, src)

      Utils.GoogleCalendar.is_google_calendar_url?(src) ->
        Embeds.embed_google_calendar(meta, raw_opts, src)

      true ->
        Embeds.embed_image(meta, raw_opts, src)
    end
  end

  defp transform_node(other, _), do: other
end
