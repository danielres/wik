defmodule WikWeb.Components.Time do
  @moduledoc """
  """

  use Phoenix.Component

  attr :open?, :boolean, default: false
  attr :class, :string, default: ""
  attr :datetime, :any, required: true

  def pretty(assigns) do
    ~H"""
    <WikWeb.Components.tooltip variant="info" position="bottom">
      {@datetime |> Utils.Time.relative()}
      <:content>
        {@datetime |> Utils.Time.absolute()}
      </:content>
    </WikWeb.Components.tooltip>
    """
  end
end
