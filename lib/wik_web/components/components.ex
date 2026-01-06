defmodule WikWeb.Components do
  @moduledoc """
  Generic WikWeb components.
  """

  use WikWeb, :html

  use Phoenix.Component

  attr :ctx, :any, required: true

  def dialog_page_not_found(assigns) do
    ~H"""
    <div class="mx-auto px-6 py-16 text-center w-svw">
      <h1 class="text-2xl">Ooopsie...</h1>
      <p class="mt-3 text-sm opacity-70">This page does not exist.</p>
      <.link
        navigate={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, %{slug: "home"})}
        class="btn mt-3"
      >
        <.icon name="hero-arrow-left-mini" /> <span>Back to wiki</span>
      </.link>
    </div>
    """
  end

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

  attr :sidebar?, :boolean, default: false
  slot :sidebar, required: false
  slot :header, required: true
  slot :inner_block, required: true

  def drawer(assigns) do
    drawer_id = "drawer-" <> Ecto.UUID.generate()
    assigns = assigns |> assign(drawer_id: drawer_id)

    ~H"""
    {render_slot(@header)}

    <div class="stacked">
      <div class="drawer drawer-open drawer-end pointer-events-none">
        <input id={@drawer_id} type="checkbox" class="drawer-toggle" />

        <div :if={@sidebar?} class="drawer-side overflow-visible">
          <div class={[
            "flex h-full",
            "is-drawer-close:w-12 md:is-drawer-close:w-64 is-drawer-open:w-64"
          ]}>
            {render_slot(@sidebar, @drawer_id)}
          </div>
        </div>
      </div>

      <div class={[
        "drawer-content",
        @sidebar? and "md:mr-64"
      ]}>
        {render_slot(@inner_block)}
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
