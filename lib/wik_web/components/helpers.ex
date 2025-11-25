defmodule WikWeb.Helpers do
  @moduledoc """
  Helper functions for Phoenix components and LiveViews.
  """

  @doc """
  Checks if a Phoenix slot has any content.

  Returns `true` if the slot contains any non-empty content,
  `false` if it's empty or only contains whitespace.

  ## Examples

      iex> WikWeb.Helpers.slot_has_content?([%{inner_block: %{static: [""]}}])
      false

      iex> WikWeb.Helpers.slot_has_content?([%{inner_block: %{static: ["Hello"]}}])
      true
  """
  @spec slot_has_content?(list()) :: boolean()
  def slot_has_content?(slot) when is_list(slot) do
    Enum.any?(slot, fn item ->
      case item do
        %{inner_block: %{static: static}} -> Enum.any?(static, &(&1 != ""))
        _ -> true
      end
    end)
  end
end
