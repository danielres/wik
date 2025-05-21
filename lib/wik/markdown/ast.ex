defmodule Wik.Markdown.Ast do
  @moduledoc """
  Extracts plain text from an Earmark AST, stripping out all tags.
  """

  @doc """
  Given an Earmark AST (a list of nodes), returns a single string
  containing only the text content.

  ## Examples

      iex> ast = ["Hello ", {"strong", [], ["world"], %{}}, "!"]
      iex> Earmark.TextExtractor.to_text(ast)
      "Hello world!"

  """
  @spec to_text(list()) :: String.t()
  def to_text(ast) when is_list(ast) do
    ast
    |> collect()
    |> IO.iodata_to_binary()
  end

  # A text node is just a binary
  defp collect(text) when is_binary(text), do: text

  # An AST node is a 4-tuple: {tag, attrs, children, meta}
  defp collect({_, _, children, _meta}), do: collect(children)

  # A list of nodes — recurse into each
  defp collect(nodes) when is_list(nodes) do
    Enum.map(nodes, &collect/1)
  end

  # Anything else (e.g. tags without children, tuples we don’t recognize) is ignored
  defp collect(_other), do: []
end
