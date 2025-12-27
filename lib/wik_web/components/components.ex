defmodule WikWeb.Components do
  @moduledoc """
  Generic WikWeb components.
  """

  use WikWeb, :html

  use Phoenix.Component

  attr :class, :string, default: ""

  def footer(assigns) do
    ~H"""
    <footer class={["footer sm:footer-horizontal", @class]}>
      <nav>
        <h6 class="footer-title">Services</h6>
        <a class="link link-hover">Branding</a>
        <a class="link link-hover">Design</a>
        <a class="link link-hover">Marketing</a>
        <a class="link link-hover">Advertisement</a>
      </nav>
      <nav>
        <h6 class="footer-title">Company</h6>
        <a class="link link-hover">About us</a>
        <a class="link link-hover">Contact</a>
        <a class="link link-hover">Jobs</a>
        <a class="link link-hover">Press kit</a>
      </nav>
      <nav>
        <h6 class="footer-title">Legal</h6>
        <a class="link link-hover">Terms of use</a>
        <a class="link link-hover">Privacy policy</a>
        <a class="link link-hover">Cookie policy</a>
      </nav>
    </footer>
    """
  end

  slot :sidebar, required: false

  def drawer(assigns) do
    ~H"""
    <div class="grid min-h-svh grid-rows-[auto_1fr]">
      {render_slot(@header)}

      <div class="drawer drawer-end drawer-open">
        <input id="my-drawer-4" type="checkbox" class="drawer-toggle" />
        <div class="drawer-content grid">
          {render_slot(@inner_block)}
        </div>

        {# <div class="drawer-side h-full is-drawer-open:overflow-visible is-drawer-close:overflow-visible"> }
        <div class="drawer-side h-full">
          <label for="my-drawer-4" aria-label="close sidebar" class="drawer-overlay"></label>
          <div class="h-full grid is-drawer-close:w-12 is-drawer-open:w-64">
            {render_slot(@sidebar)}
          </div>
        </div>
      </div>
    </div>
    """
  end

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
        class="dropdown-content z-10 mt-2"
      >
        {render_slot(@content)}
      </div>
    </div>
    """
  end

  attr :open?, :boolean, default: false
  attr :class, :string, default: ""
  attr :position, :string, default: "top"
  attr :variant, :string, default: "base-300"
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
