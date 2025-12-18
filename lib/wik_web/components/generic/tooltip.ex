defmodule WikWeb.Components do
  @moduledoc """
  Generic tooltip wrapper.

  - Inner block renders the trigger.
  - The `:content` slot renders tooltip content. 
  """

  use Phoenix.Component

  attr :open?, :boolean, default: false
  attr :class, :string, default: ""
  attr :position, :string, default: "top"
  attr :variant, :string, default: "neutral"
  slot :inner_block, required: true
  slot :content, required: true

  def tooltip(assigns) do
    position_class =
      case assigns.position do
        "top" -> "tooltip-top"
        "bottom" -> "tooltip-bottom"
        "left" -> "tooltip-left"
        "right" -> "tooltip-right"
        _ -> "tooltip-top"
      end

    variant_class =
      case assigns.variant do
        "neutral" -> "tooltip-neutral"
        "primary" -> "tooltip-primary"
        "secondary" -> "tooltip-secondary"
        "accent" -> "tooltip-accent"
        "info" -> "tooltip-info"
        "success" -> "tooltip-success"
        "warning" -> "tooltip-warning"
        "error" -> "tooltip-error"
        _ -> "tooltip-neutral"
      end

    assigns =
      assigns
      |> assign(
        position_class: position_class,
        variant_class: variant_class
      )

    ~H"""
    <div class={[
      "tooltip",
      @position_class,
      @variant_class,
      @open? && "tooltip-open"
    ]}>
      <span class={["cursor-pointer", @class]}>
        {render_slot(@inner_block)}
      </span>

      <div class="tooltip-content" style="font-size: inherit">
        {render_slot(@content)}
      </div>
    </div>
    """
  end
end
