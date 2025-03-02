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
    grid_rows =
      if assigns[:menu],
        do: "grid-rows-[auto,auto,1fr]",
        else: "grid-rows-[auto,1fr]"

    ~H"""
    <div class={ "#{ grid_rows } min-h-[100vh] grid pb-12 md:pb-0 gap-4" }>
      <header class="bg-slate-200 py-2 px-4">
        <div class="mx-auto max-w-2xl flex justify-between items-end">
          <h1 class="flex gap-2 items-center">
            {render_slot(@header_left)}
          </h1>
          <div>
            {render_slot(@header_right)}
          </div>
        </div>
      </header>

      <%= if @menu do %>
        <div class=" grid max-w-2xl mx-auto w-full">
          {render_slot(@menu)}
        </div>
      <% end %>

      <main class="grid max-w-2xl mx-auto w-full">
        {render_slot(@main)}
      </main>
    </div>
    """
  end

  attr :variant, :string, default: "card", values: ["card", "transparent"]
  slot :inner_block, required: true

  def card(assigns) do
    variant =
      if assigns[:variant] == "transparent",
        do: "",
        else: "bg-white shadow rounded"

    ~H"""
    <div class={ "py-6 sm:px-6 px-4 lg:px-8 #{variant}" }>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:user_photo_url, :string, required: true)

  def avatar(assigns) do
    ~H"""
    <a href={~p"/me"}>
      <img src={@user_photo_url} alt="user photo" class="w-10 h-10 rounded-full" />
    </a>
    """
  end
end
