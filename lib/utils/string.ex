defmodule Utils.String do
  @moduledoc """
  String utility functions for text manipulation.
  """

  @doc """
  Capitalizes the first grapheme of a string.

  Returns an empty string if the input is empty.

  ## Examples

      iex> Utils.String.titleize("hello")
      "Hello"

      iex> Utils.String.titleize("élephant")
      "Élephant"

      iex> Utils.String.titleize("")
      ""
  """
  @spec titleize(String.t()) :: String.t()
  def titleize(str) do
    case String.next_grapheme(str) do
      {first, rest} -> String.upcase(first) <> rest
      nil -> ""
    end
  end
end
