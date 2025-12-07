defmodule WikWeb.Components.Layout.StickyToolbar do
  use Phoenix.Component
  use WikWeb, :live_view
  alias Phoenix.LiveView.JS

  slot :inner_block, required: false

  @impl true
  def render(assigns) do
    ~H"""
    <div id="layout-sticky-toolbar-sentinel" />
    <div
      id="LayoutStickyToolbar"
      phx-hook="LayoutStickyToolbar"
      class={[
        "layout-sticky-toolbar",
        (WikWeb.Helpers.slot_has_content?(@inner_block) &&
           "block") || "hidden"
      ]}
    >
      <div class="layout-sticky-toolbar-inner">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
