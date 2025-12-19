defmodule WikWeb.Components do
  @moduledoc """
  Generic tooltip wrapper.

  - Inner block renders the trigger.
  - The `:content` slot renders tooltip content. 
  """

  use WikWeb, :html

  use Phoenix.Component
  attr :open?, :boolean, default: false
  attr :class, :string, default: ""
  attr :position, :string, default: "bottom"
  attr :variant, :string, default: "neutral"
  slot :inner_block, required: true
  slot :content, required: true

  def dropdown(assigns) do
    position_class =
      case assigns.position do
        "top" -> "dropdown-top"
        "bottom" -> "dropdown-bottom"
        "left" -> "dropdown-left"
        "right" -> "dropdown-right"
        "end" -> "dropdown-end"
        _ -> "dropdown-bottom"
      end

    assigns =
      assigns
      |> assign(position_class: position_class)

    ~H"""
    <div class={["dropdown", @position_class]}>
      <div tabindex="0" class="cursor-pointer">
        {render_slot(@inner_block)}
      </div>

      <div
        tabindex="-1"
        class="dropdown-content z-1 mt-2"
      >
        {render_slot(@content)}
      </div>
    </div>
    """
  end

  attr :open?, :boolean, default: false
  attr :class, :string, default: ""
  attr :position, :string, default: "top"
  # attr :variant, :string, default: "base-300"
  attr :variant, :string, default: "accent"
  attr :offset, :string, default: "0.75rem"
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
        "base-100" -> "[--tt-bg:var(--color-base-100)]"
        "base-200" -> "[--tt-bg:var(--color-base-200)]"
        "base-300" -> "[--tt-bg:var(--color-base-300)]"
        _ -> "tooltip-neutral"
      end

    assigns =
      assigns
      |> assign(
        position_class: position_class,
        variant_class: variant_class
      )

    ~H"""
    <div
      class={[
        "tooltip",
        @position_class,
        @variant_class,
        @open? && "tooltip-open"
      ]}
      style={"
      --custom-offset: #{@offset};
      --tt-off: calc(100% + 0.5rem + var(--custom-offset));     
      --tt-tail: calc(100% + 1px + 0.25rem + var(--custom-offset));
      "}
    >
      <span class={["cursor-pointer", @class]}>
        {render_slot(@inner_block)}
      </span>

      <div
        class="tooltip-content"
        style="font-size: inherit"
      >
        {render_slot(@content)}
      </div>
    </div>
    """
  end
end
