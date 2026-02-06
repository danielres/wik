# TODO: move out of PageTree to FormMarkdown

defmodule Wik.Wiki.PageTree.Markdown do
  @moduledoc """
  Translates between user-facing [[path]] links and stored wikid links.

  This is intentionally used at the DB edge (LiveView load/save only for POC).
  """

  alias Wik.Wiki.PageTree.Markdown.Utils, as: Md

  @wikid_regex ~r/\[[^\]]*\]\(wikid:([^\)]+)\)/u

  @spec rewrite_wikid_to_wikilinks(String.t() | nil, map()) :: String.t()
  @doc """
  Converts stored wikid links to user-friendly `[[path]]` links.
  Unknown ids are left untouched so the original markdown is preserved.
  """
  def rewrite_wikid_to_wikilinks(markdown, tree_by_id \\ %{}) do
    text = markdown || ""

    Regex.replace(@wikid_regex, text, fn full, id ->
      case Map.get(tree_by_id, id) do
        %{path: path} when is_binary(path) and path != "" ->
          "[[#{path}]]"

        _ ->
          full
      end
    end)
  end

  @spec rewrite_wikilinks_to_wikid(String.t() | nil, map()) :: String.t()
  @doc """
  Rewrites `[[path]]` links to `wikid:` links using a path map.
  Skips fenced/indented code blocks and only rewrites when a path is resolvable.
  """
  def rewrite_wikilinks_to_wikid(markdown, path_map) do
    text = markdown || ""
    links = extract_wikilinks(text)

    if links == [] do
      text
    else
      {lines, _links, _state} =
        text
        |> String.split("\n", trim: false)
        |> Enum.reduce({[], links, %{fenced?: false, fence: nil}}, fn line,
                                                                      {acc, pending, state} ->
          {state, fence_line?} = Md.update_fence_state(state, line)

          if fence_line? or state.fenced? or Md.indented_code_line?(line) do
            {[line | acc], pending, state}
          else
            {rewritten, pending} = Md.rewrite_line(line, pending, path_map)
            {[rewritten | acc], pending, state}
          end
        end)

      lines |> Enum.reverse() |> Enum.join("\n")
    end
  end

  @spec extract_wikilinks(String.t() | nil) :: list(%{target: String.t(), label: String.t()})
  @doc """
  Extracts `[[path]]` links from markdown.
  Returns a list of `%{target, label}` maps and falls back to `[]` on parse errors.
  """
  def extract_wikilinks(markdown) do
    text = markdown || ""

    case Earmark.Parser.as_ast(text, wikilinks: true) do
      {:ok, ast, _} -> ast |> Md.collect_wikilinks([]) |> Enum.reverse()
      {:error, ast, _} -> ast |> Md.collect_wikilinks([]) |> Enum.reverse()
      _ -> []
    end
  end
end
