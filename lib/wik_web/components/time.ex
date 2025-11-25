defmodule WikWeb.Components.Time do
  @moduledoc """
  """

  use Phoenix.Component

  attr :open?, :boolean, default: false

  def pretty(assigns) do
    ~H"""
    <div class={["tooltip tooltip-info tooltip-bottom tooltip-neutral", @open? && "tooltip-open"]}>
      <span class="cursor-pointer">
        {@datetime |> Utils.Time.relative()}
      </span>
      <div class="tooltip-content" style="font-size: inherit">
        {@datetime |> Utils.Time.absolute()}
      </div>
    </div>
    """
  end
end
