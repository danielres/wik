defmodule Wik.Tags.PageToTag.Parser do
  @moduledoc """
  Extract tags from wiki page text (ATX headers only).

  Rules:
    - ATX headers: lines starting with 1–6 "#" + space.
    - Tags at end of header: tokens matching ~r/#([A-Za-z0-9_-]+)/.
    - Tags are downcased.
  """

  @header_regex ~r/^(\#{1,6})\s+(.+)$/
  @tag_regex ~r/#([A-Za-z0-9_-]+)/u

  @spec extract_tags(String.t()) :: [String.t()]
  def extract_tags(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.reduce(MapSet.new(), fn line, acc ->
      case Regex.run(@header_regex, line) do
        [_, _hashes, title] ->
          @tag_regex
          |> Regex.scan(title)
          |> Enum.reduce(acc, fn [_, tag], acc2 -> MapSet.put(acc2, String.downcase(tag)) end)

        _ ->
          acc
      end
    end)
    |> MapSet.to_list()
  end
end
