defmodule Wik.Markdown do
  @moduledoc """
  A module for parsing markdown using Earmark,
  specifically transforming wiki links like [[Some Link]]
  into HTML <a> tags with a specified base path.
  """

  alias Earmark.Parser
  alias Earmark.Transform
  alias Wik.Utils

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
    if String.match?(href, ~r/^[a-zA-Z0-9 ]+$/) do
      slug = href |> Utils.slugify()
      {"a", [{"href", Path.join(base_path, slug)}], children, meta}
    else
      node
    end
  end

  defp transform_node({"a", _attrs, _children, _meta} = node, _base_path),
    do: node

  defp transform_node(other, _base_path),
    do: other
end
