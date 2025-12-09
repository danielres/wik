defmodule WikWeb.Components.Layout.StickyToolbar do
  use Phoenix.Component
  use WikWeb, :live_view

  attr :block, :any, required: false

  @impl true
  def render(assigns) do
    ~H"""
    <div id="layout-sticky-toolbar-sentinel" />
    <div
      id="LayoutStickyToolbar"
      phx-hook="LayoutStickyToolbar"
      class={[
        "layout-sticky-toolbar",
        (WikWeb.Helpers.slot_has_content?(@block) &&
           "block") || "hidden"
      ]}
    >
      <div class="layout-sticky-toolbar-inner">
        {render_slot(@block)}
      </div>
    </div>
    """
  end
end
