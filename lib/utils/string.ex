defmodule Utils.String do
  def titleize(str) do
    case String.next_grapheme(str) do
      {first, rest} -> String.upcase(first) <> rest
      nil -> ""
    end
  end
end
