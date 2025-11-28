defmodule WikWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WikWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :ctx, :any

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true
  slot :aside

  def app(assigns) do
    ~H"""
    <header class="layout-header">
      <div class="flex justify-between w-full">
        <div class="flex items-center gap-2 mt-2 font-bold text-sm">
          <%= if @ctx[:current_group] do %>
            <.link
              class="opacity-50 hover:opacity-100 transition"
              navigate={~p"/"}
            >
              Groups
            </.link>

            <span class="opacity-50">/</span>
            <.link
              class="opacity-50 hover:opacity-100 transition"
              navigate={~p"/#{@ctx.current_group.slug}"}
            >
              {@ctx.current_group.title}
            </.link>
          <% end %>
        </div>
        <div>
          <div class="dropdown dropdown-end mt-2 text-sm">
            <div
              tabindex="0"
              role="button"
              class="opacity-50 hover:opacity-100 transition cursor-pointer font-bold"
            >
              {@ctx.current_user |> to_string}
            </div>

            <div
              tabindex="0"
              class="dropdown-content card card-sm bg-base-100 z-1 w-48 shadow-md mt-2"
            >
              <div class="card-body bg-base-200 rounded-lg">
                <.link
                  navigate={~p"/sign-out"}
                  class="flex gap-3 justify-center items-center hover:bg-white/5 transition px-2 py-2 rounded opacity-80 hover:opacity-100"
                >
                  <span>Log out</span>
                  <.icon name="hero-chevron-right size-4" />
                </.link>

                <hr class="opacity-20 my-2" />

                <div class="py-2 space-y-4 flex flex-col items-center opacity-80 hover:opacity-100">
                  <div>Theme</div>
                  <div class=""><.theme_toggle /></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%= if(@ctx[:current_group]) do %>
        <div class="flex gap-2 items-center justify-between">
          <div>
            <.link
              class="btn"
              navigate={~p"/#{@ctx.current_group.slug}/pages/home"}
            >
              Home
            </.link>

            <.link class="btn" navigate={~p"/#{@ctx.current_group.slug}/members"}>Members</.link>
          </div>
        </div>
      <% end %>
    </header>

    <main class="layout-main">
      {render_slot(@inner_block)}

      <div class="mt-8 border-t-4 border-base-content/10 pt-8 flex justify-between">
        <WikWeb.Components.OnlineUsers.list presences={@ctx[:presences]} />
        <.link
          :if={@ctx[:page_slug]}
          class="btn btn-xs"
          navigate={~p"/#{@ctx.current_group.slug}/pages"}
        >
          All pages
        </.link>
      </div>
    </main>

    <Toast.toast_group flash={@flash} theme="dark" animation_duration={200} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
