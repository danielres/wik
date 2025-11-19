defmodule WikWeb.Helpers do
  def slot_has_content?(slot) when is_list(slot) do
    Enum.all?(slot, fn item ->
      case item do
        %{inner_block: %{static: static}} -> Enum.all?(static, &(&1 == ""))
        _ -> true
      end
    end)
  end
end
