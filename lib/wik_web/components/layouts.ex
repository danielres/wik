defmodule WikWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WikWeb, :html

  alias WikWeb.GroupLive.PageLive.Show.ActionButton

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

  attr :title, :string, required: false
  attr :class, :string, default: ""
  attr :icon, :string, required: false
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div class={["px-6 py-4 border-b border-base-100", @class]}>
      <h6 :if={assigns[:title]} class="flex items-center gap-2 mb-2">
        <.icon :if={assigns[:icon]} name={@icon} />
        <span class="uppercase tracking-wide text-xs">{@title}</span>
      </h6>

      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :ctx, :any, required: true
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :backdrop?, :boolean, default: false
  attr :open?, :boolean, default: true
  slot :inner_block, required: true
  slot :backdrop, required: false
  slot :panels, required: false
  slot :actions, required: false

  def drawer2(assigns) do
    ~H"""
    <div class="stacked items-start overflow-clip">
      <div :if={@backdrop?}>{render_slot(@backdrop)}</div>

      <div class="grid grid-rows-[auto_1fr] min-h-svh">
        <.layout_header ctx={@ctx} class="px-4 sm:px-6 lg:px-8" />

        <div class={["drawer2", @open? and "drawer2-open"]}>
          <div class="drawer2-content stacked">
            <div class="stacked">
              <div class="grid md:mr-64 ">
                <main class="px-4 sm:px-6 lg:px-8">
                  {render_slot(@inner_block)}
                </main>

                {# footer ============}
                {# <WikWeb.Components.footer class="mt-auto pt-8 border-t border-base-100" /> }
              </div>

              {# sidebar backdrop ============}
              <div
                :if={@open?}
                phx-click="toggle_open?"
                class="bg-base-300/30 hover:bg-base-300/20 transition relative md:hidden cursor-pointer"
              />
            </div>

            <div class="grid grid-cols-[1fr_auto]">
              {# = ACTIONS ==================================================== }
              <div class="sticky top-0 h-min pointer-events-none [&>*>*]:pointer-events-auto">
                <div class="flex justify-end">
                  {render_slot(@actions)}
                </div>
              </div>

              {# = PANELS ==================================================== }
              <div class={[
                "bg-base-300/70 w-0 md:w-64 backdrop-blur transition-all ",
                @open? and "w-64"
              ]}>
                <div class="sticky top-0 w-64">
                  {render_slot(@panels)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <Toast.toast_group flash={@flash} theme="dark" animation_duration={200} />
    """
  end

  attr :ctx, :any, required: true
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :sidebar?, :boolean, default: false
  attr :backdrop?, :boolean, default: false
  slot :sticky_toolbar, required: false
  slot :inner_block, required: true
  slot :sidebar, required: false
  slot :backdrop, required: false

  def drawer(assigns) do
    ~H"""
    <div class={@backdrop? and "stacked min-h-svh"}>
      <div :if={@backdrop?}>
        {render_slot(@backdrop)}
      </div>

      <div class={@backdrop? and "pointer-events-none [&>*>*>*]:pointer-events-auto"}>
        <WikWeb.Components.drawer sidebar?={@sidebar?}>
          {render_slot(@sticky_toolbar)}

          <:header>
            <.layout_header ctx={@ctx} />
          </:header>

          {render_slot(@inner_block)}
          {# <WikWeb.Components.footer class="mt-auto pt-8 border-t border-base-100" /> }

          <:sidebar :let={drawer_id}>{render_slot(@sidebar, drawer_id)}</:sidebar>
        </WikWeb.Components.drawer>
      </div>
    </div>

    <Toast.toast_group flash={@flash} theme="dark" animation_duration={200} />
    """
  end

  slot :title, required: false
  slot :subtitle, required: false
  slot :inner_block, required: true

  def page_container(assigns) do
    ~H"""
    <div class="grid grid-cols-[1fr_min(75ch,100%)_1fr] [&>*]:col-start-2 [&>*]:px-6">
      <header class="mt-16 mb-6">
        <h1 :if={@title != []} class="text-3xl">{render_slot(@title)}</h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </header>

      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: ""
  attr :ctx, :any, required: true

  defp layout_header(assigns) do
    ~H"""
    <nav class={[
      @class,
      "bg-base-300 pb-2",
      "space-y-2"
    ]}>
      <div class="flex justify-between w-full">
        <div class="flex items-center gap-1 mt-2 font-bold text-xs">
          <%= if @ctx[:current_group] do %>
            <.link class="opacity-50 hover:opacity-100 transition" navigate={~p"/"}>
              Groups
            </.link>

            <.icon name="hero-chevron-right-micro" class="opacity-40" />

            <.link
              class={[link_class(@ctx, "", false)]}
              navigate={~p"/#{@ctx[:current_group].slug}"}
            >
              {@ctx[:current_group].title}
            </.link>
          <% end %>
        </div>

        <WikWeb.Components.dropdown position="end">
          <span class="opacity-50 hover:opacity-100 transition cursor-pointer font-semibold text-xs">
            {@ctx.current_user |> to_string}
          </span>
          <:content>
            <div class="card card-sm w-48 shadow-md">
              <div class="card-body bg-base-300 rounded-lg">
                <.link
                  navigate={~p"/sign-out"}
                  class="flex gap-3 justify-center items-center hover:bg-white/5 transition px-2 py-2 rounded opacity-80 hover:opacity-100"
                >
                  <span>Log out</span>
                  <.icon name="hero-chevron-right" />
                </.link>

                <hr class="opacity-20 my-2" />

                <div class="py-2 space-y-4 flex flex-col items-center opacity-80 hover:opacity-100">
                  <div>Theme</div>
                  <div><.theme_toggle /></div>
                </div>
              </div>
            </div>
          </:content>
        </WikWeb.Components.dropdown>
      </div>

      <%= if(@ctx[:current_group]) do %>
        <div class="flex gap-4">
          <%= if link_active?(@ctx, "/wiki") or link_active?(@ctx, "/map") do %>
            <WikWeb.Components.dropdown>
              <.link
                class={[link_class(@ctx, "/wiki"), "group"]}
                navigate={~p"/#{@ctx[:current_group].slug}/wiki/home"}
              >
                Wiki
                <.icon
                  name="hero-chevron-down-micro"
                  class="opacity-50 group-hover:opacity-100 transition"
                />
              </.link>

              <:content>
                <ul class={[
                  "menu bg-base-300 rounded backdrop-blur",
                  "text-sm [&_a]:whitespace-nowrap",
                  "[&_.icon]:opacity-50"
                ]}>
                  <li>
                    <.link navigate={~p"/#{@ctx[:current_group].slug}/wiki/home"}>
                      <.icon name="hero-home-mini" /> Home
                    </.link>
                  </li>

                  <li>
                    <.link navigate={~p"/#{@ctx.current_group.slug}/tree"}>
                      <.icon name="hero-folder-mini" /> Tree
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/#{@ctx.current_group.slug}/wiki"}>
                      <.icon name="hero-book-open-mini" /> All pages
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/#{@ctx.current_group.slug}/map"}>
                      <.icon name="hero-map-pin-mini" /> Map
                    </.link>
                  </li>
                </ul>
              </:content>
            </WikWeb.Components.dropdown>
          <% else %>
            <.link
              class={[link_class(@ctx, "/wiki")]}
              navigate={~p"/#{@ctx[:current_group].slug}/wiki/home"}
            >
              Wiki
            </.link>
          <% end %>

          <.link
            class={[link_class(@ctx, "/tags")]}
            navigate={~p"/#{@ctx[:current_group].slug}/tags"}
          >
            Tags
          </.link>

          <.link
            class={[link_class(@ctx, "/members")]}
            navigate={~p"/#{@ctx[:current_group].slug}/members"}
          >
            Members
          </.link>
        </div>
      <% end %>
    </nav>
    """
  end

  defp link_active?(ctx, suffix, subpaths? \\ true) do
    path = ctx[:current_path] || ""

    base =
      case ctx[:current_group] do
        %{slug: slug} -> "/#{slug}#{suffix}"
        _ -> nil
      end

    if subpaths? do
      (path != "" and base) && String.starts_with?(path, base)
    else
      (path != "" and base) && path == base
    end
  end

  defp link_class(ctx, suffix, subpaths? \\ true) do
    active? = link_active?(ctx, suffix, subpaths?)
    base_class = "font-semibold transition hover:opacity-100"
    active_class = "#{base_class}"
    inactive_class = "#{base_class} opacity-50"
    if active?, do: active_class, else: inactive_class
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
