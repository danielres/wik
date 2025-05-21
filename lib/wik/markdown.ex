defmodule Wik.Markdown do
  @moduledoc """
  A module for parsing Markdown using Earmark,
  transforming wiki links into HTML <a> tags,
  and supporting custom embeds using Markdown image syntax.
  """

  alias Earmark.Parser
  alias Earmark.Transform
  alias Wik.Utils
  alias Wik.Markdown.Ast
  alias Wik.Markdown.Embeds

  @doc """
  Sanitizes raw Markdown to safe HTML.
  """
  def sanitize(markdown) do
    markdown
    |> HtmlSanitizeEx.markdown_html()
    |> preserve_html_entities()
  end

  def cleanup(markdown) do
    markdown
    |> String.trim()
    |> String.replace(~r/(\n\s*){3,}/, "\n\n")
  end

  defp preserve_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  def to_html(markdown, base_path, page_slug) do
    to_ast(markdown, base_path, [page_slug])
    |> Enum.map_join("", &Transform.transform/1)
  end

  def to_ast(markdown, base_path, embedded_pages) do
    case Parser.as_ast(markdown, wikilinks: true) do
      {:ok, ast, _msgs} ->
        ast
        |> List.wrap()
        |> Transform.map_ast(&transform_node(&1, base_path, embedded_pages), true)

      _ ->
        {:error, "Unexpected return from Parser.as_ast/2"}
    end
  end

  defp transform_node({"a", [{"href", href}], children, meta}, base_path, _embedded_pages) do
    max_length = 40

    simple_link? =
      case children do
        [text] when is_binary(text) and text == href -> true
        _ -> false
      end

    truncated_text =
      if simple_link? and String.length(href) > max_length do
        String.slice(href, 0, max_length) <> "..."
      else
        href
      end

    final_children = if simple_link?, do: [truncated_text], else: children

    if Utils.Href.external?(href) do
      if simple_link? do
        {:replace, {"a", [{"href", href}], final_children, meta}}
      else
        {"a", [{"href", href}], children, meta}
      end
    else
      slug = Utils.slugify(href)

      if simple_link? do
        {:replace, {"a", [{"href", Path.join(base_path, slug)}], final_children, meta}}
      else
        {"a", [{"href", Path.join(base_path, slug)}], children, meta}
      end
    end
  end

  defp transform_node({"a", _, _, _} = node, _base_path, _embedded_pages), do: node

  defp transform_node({"img", attrs, _children, meta}, _base_path, _embedded_pages) do
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

  defp transform_node({"p", attrs, children, meta}, base_path, embedded_pages) do
    case children do
      ["!", {"a", [{"href", page_name}], [node], _} | _] ->
        Embeds.embed_page(meta, base_path, page_name, node, embedded_pages)

      _ ->
        {"p", attrs, children, meta}
    end
  end

  defp transform_node(node = {"h1", _, _, _}, bp, ep), do: add_anchor(node, bp, ep)
  defp transform_node(node = {"h2", _, _, _}, bp, ep), do: add_anchor(node, bp, ep)
  defp transform_node(node = {"h3", _, _, _}, bp, ep), do: add_anchor(node, bp, ep)
  defp transform_node(node = {"h4", _, _, _}, bp, ep), do: add_anchor(node, bp, ep)
  defp transform_node(node = {"h5", _, _, _}, bp, ep), do: add_anchor(node, bp, ep)
  defp transform_node(node = {"h6", _, _, _}, bp, ep), do: add_anchor(node, bp, ep)

  defp transform_node(other, _, _), do: other

  defp add_anchor({tag, attrs, children, meta}, _, eb) do
    icon = [{"i", [{"class", "hero-link"}], [], %{}}]
    icon_wrapper = [{"div", [{"class", "icon"}], icon, %{}}]
    prefix = eb |> Enum.reverse() |> tl() |> Enum.join("_")
    slug = children |> Ast.to_text() |> Utils.slugify()
    id = [prefix, slug] |> Enum.reject(&(&1 == "")) |> Enum.join("_")
    link = [{"a", [{"href", "##{id}"}, {"class", "anchored"}], [children, icon_wrapper], %{}}]
    attrs = [{"id", id} | attrs]
    {:replace, {tag, attrs, link, meta}}
  end
end
