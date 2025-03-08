defmodule WikWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use WikWeb, :controller` and
  `use WikWeb, :live_view`.
  """
  use WikWeb, :html

  embed_templates("layouts/*")

  slot(:main, required: true)
  slot(:header_left, required: true)
  slot(:header_right, required: true)
  slot(:menu)

  def app_layout(assigns) do
    class = if assigns[:menu], do: "grid-rows-[auto,auto,1fr]", else: "grid-rows-[auto,1fr]"
    assigns = assigns |> assign(:class, class)

    ~H"""
    <div class={ "#{ @class } min-h-[100vh] grid pb-12 md:pb-0 gap-4" }>
      <header class="bg-slate-200 py-2 px-4">
        <div class="mx-auto max-w-screen-md flex justify-between items-end">
          <h1 class="flex gap-2 items-center">
            {render_slot(@header_left)}
          </h1>
          <div>
            {render_slot(@header_right)}
          </div>
        </div>
      </header>

      <%= if @menu do %>
        <div class="grid max-w-screen-md mx-auto w-full px-4 md:px-0">
          {render_slot(@menu)}
        </div>
      <% end %>

      <main class="grid max-w-screen-md mx-auto w-full">
        {render_slot(@main)}
      </main>
    </div>
    """
  end

  attr :variant, :string, default: "card", values: ["card", "transparent"]
  slot :inner_block, required: true

  def card(assigns) do
    class = if assigns[:variant] == "transparent", do: "", else: "bg-white shadow md:rounded"
    assigns = assigns |> assign(:class, class)

    ~H"""
    <div class={ "py-6 sm:px-6 px-4 lg:px-8 #{@class}" }>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:group_slug, :string, required: true)
  attr(:page_slug, :string, required: true)

  def page_slug(assigns) do
    ~H"""
    <div class="text-sm text-slate-600 flex gap-0.5 items-center">
      <.link patch={~p"/#{@group_slug}/wiki"} class="opacity-60 hover:underline">
        wiki
      </.link>
      <span class="text-xs">/</span>
      <span class="">{@page_slug}</span>
    </div>
    """
  end
end
