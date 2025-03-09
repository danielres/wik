defmodule WikWeb.Page.ShowLive do
  use WikWeb, :live_view

  alias Wik.Page
  require Logger

  def make_route(group_slug, slug), do: ~p"/#{group_slug}/wiki/#{slug}"

  @impl true
  def mount(%{"group_slug" => group_slug, "slug" => page_slug}, session, socket) do
    Phoenix.PubSub.subscribe(Wik.PubSub, "pages")

    user = session["user"]
    group_name = Wik.get_group_name(group_slug)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:page_slug, page_slug)
     |> assign(:page_title, "#{page_slug} | #{group_name}")
     |> assign(:backlinks, Page.backlinks(group_slug, page_slug))
     |> assign(:group_slug, group_slug)
     |> assign(:group_name, Wik.get_group_name(group_slug))}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => page_slug}, _uri, socket) do
    # TODO: trim markdown when saving instead
    markdown = Page.load(group_slug, page_slug) |> String.trim()
    rendered = Page.render(group_slug, markdown)
    socket = socket |> assign(:content, rendered) |> assign(:markdown, markdown)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_updated, _user, group_slug, slug, new_content}, socket) do
    if socket.assigns.group_slug == group_slug && socket.assigns.page_slug == slug do
      rendered = Page.render(group_slug, new_content)
      {:noreply, socket |> assign(content: rendered)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_layout>
      <:header_left>
        <a
          href={~p"/#{@group_slug}"}
          class="flex text-slate-500 hover:text-slate-600"
          style="font-variant: small-caps"
        >
          {@group_name}
        </a>
      </:header_left>

      <:header_right>
        <Components.avatar user_photo_url={@user.photo_url} />
      </:header_right>

      <:menu>
        <div class="flex justify-between items-end">
          <Layouts.page_slug group_slug={@group_slug} page_slug={@page_slug} />

          <div class="flex gap-3">
            <Components.shortcut key="h">
              <.link
                href={~p"/#{@group_slug}/wiki/#{@page_slug}/revisions"}
                class="block p-2 rounded-full bg-slate-200 opacity-30 hover:opacity-75"
                title="History"
              >
                <i class="hero-clock">History</i>
              </.link>
            </Components.shortcut>

            <Components.shortcut key="e">
              <.link
                href={~p"/#{@group_slug}/wiki/#{@page_slug}/edit"}
                class="block p-2 rounded-full bg-slate-200/75 hover:bg-slate-200"
                title="Edit page"
              >
                <i class="hero-pencil-solid text-slate-600">Edit</i>
              </.link>
            </Components.shortcut>
          </div>
        </div>
      </:menu>

      <:main>
        <div class="grid grid-rows-[1fr_auto] gap-4">
          <Layouts.card tabindex="1" class="">
            <div class="float-right md:bg-slate-50 pl-8 pb-12 -mr-2 relative">
              <div class="absolute right-0 -top-3 sm:-right-3">
                <Components.toggle_source_button phx-click={
                  JS.toggle(to: "#source-markdown")
                  |> JS.toggle(to: "#content-html")
                  |> JS.toggle(to: "#backlinks-widget")
                } />
              </div>
              <Components.backlinks_widget
                class=""
                id="backlinks-widget"
                group_slug={@group_slug}
                backlinks_slugs={@backlinks}
              />
            </div>

            <div id="content-html" class="">
              <Components.prose>{raw(@content)}</Components.prose>

              <div class="clear-both"></div>
            </div>

            <div id="source-markdown" class="hidden font-mono whitespace-pre-line">
              {@markdown}
            </div>
          </Layouts.card>
          <Layouts.card
            :if={length(@backlinks) > 0}
            tabindex="2"
            variant="transparent"
            class="grid gap-2 bg-slate-100 sm:hidden"
          >
            <h2 class="text-sm  text-slate-600">Backlinks</h2>

            <Components.backlinks_list
              class="grid grid-cols-2 gap-y-2 gap-x-4"
              group_slug={@group_slug}
              backlinks_slugs={@backlinks}
            />
          </Layouts.card>
        </div>
      </:main>
    </Layouts.app_layout>
    """
  end
end
