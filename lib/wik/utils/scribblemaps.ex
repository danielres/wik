defmodule Wik.Utils.Scribblemaps do
  @moduledoc """
  Utilities to embed Scribblemaps maps links in Markdown.
  """

  @spec is_scribblemaps_url?(String.t()) :: boolean()
  def is_scribblemaps_url?(url) when is_binary(url) do
    String.contains?(url, "widgets.scribblemaps.com")
  end

  def is_scribblemaps_url?(_), do: false
end
