defmodule Wik.Wiki.PageTree.Markdown do
  @moduledoc """
  Translates between user-facing [[path]] links and stored wikid links.

  This is intentionally used at the DB edge (LiveView load/save only for POC).
  """

  @wikid_regex ~r/\[[^\]]*\]\(wikid:([^\)]+)\)/u

  @spec to_editor(String.t() | nil, map()) :: String.t()
  def to_editor(markdown, tree_by_id \\ %{}) do
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

end
