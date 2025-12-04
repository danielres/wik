defmodule WikWeb.Components.Time do
  @moduledoc """
  """

  use Phoenix.Component

  attr :open?, :boolean, default: false
  attr :class, :string, default: ""
  attr :datetime, :any, required: true

  def pretty(assigns) do
    ~H"""
    <div class={["tooltip tooltip-info tooltip-bottom tooltip-neutral", @open? && "tooltip-open"]}>
      <span class={["cursor-pointer", @class]}>
        {@datetime |> Utils.Time.relative()}
      </span>

      <div class="tooltip-content" style="font-size: inherit">
        {@datetime |> Utils.Time.absolute()}
      </div>
    </div>
    """
  end
end
