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
    {:noreply,
     socket
     |> assign(:content, Page.load_rendered(group_slug, page_slug))}
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
                class="block p-2 rounded-full bg-slate-200 opacity-30"
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
        <div class="grid ">
          <Layouts.card tabindex="1" class="">
            <div
              :if={@backlinks && length(@backlinks) > 0}
              class="float-right bg-white border p-6 py-5 rounded space-y-2 ml-8 mb-8 max-w-52 overflow-hidden"
            >
              <h2 class="text-xs font-semibold text-slate-500">Backlinks</h2>

              <ul class="text-sm space-y-2">
                <%= for slug <- @backlinks do %>
                  <li>
                    <a
                      class="text-blue-600 hover:underline opacity-75 hover:opacity-100 leading-none block"
                      href={~p"/#{@group_slug}/wiki/#{slug}"}
                    >
                      {slug}
                    </a>
                  </li>
                <% end %>
              </ul>
            </div>

            <Components.prose>{raw(@content)}</Components.prose>

            <div class="clear-both"></div>
          </Layouts.card>
        </div>
      </:main>
    </Layouts.app_layout>
    """
  end
end
