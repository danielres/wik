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
    if external_href?(href) do
      node
    else
      slug = href |> Utils.slugify()
      {"a", [{"href", Path.join(base_path, slug)}], children, meta}
    end
  end

  defp transform_node({"a", _attrs, _children, _meta} = node, _base_path), do: node

  defp transform_node(other, _base_path), do: other

  defp external_href?(href) do
    String.starts_with?(href, [
      "http",
      "https",
      "/",
      "//",
      "mailto:",
      "tel:",
      "ftp:",
      "sftp:",
      "git:",
      "file:",
      "data:"
    ])
  end
end
