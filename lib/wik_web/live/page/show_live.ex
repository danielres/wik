defmodule WikWeb.Page.ShowLive do
  use WikWeb, :live_view

  alias Wik.Page
  alias WikWeb.Components
  require Logger

  @impl true
  def mount(_params, session, socket) do
    user = session["user"] || %{}

    Phoenix.PubSub.subscribe(Wik.PubSub, "pages")

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:backlinks, [])}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => page_slug}, _uri, socket) do
    {page_title, content} =
      case Page.load(group_slug, page_slug) do
        {:ok, {_metadata, body}} ->
          {page_slug, Page.render(group_slug, body)}

        :not_found ->
          {page_slug, nil}
      end

    {:noreply,
     socket
     |> assign(group_slug: group_slug)
     |> assign(slug: page_slug)
     |> assign(group_name: Wik.get_group_name(group_slug))
     |> assign(:backlinks, Page.backlinks(group_slug, page_slug))
     |> assign(:page_title, page_title)
     |> assign(:content, content)}
  end

  @impl true
  def handle_info({:page_updated, _user, group_slug, slug, new_content}, socket) do
    if socket.assigns.group_slug == group_slug && socket.assigns.slug == slug do
      rendered = Page.render(group_slug, new_content)
      {:noreply, socket |> assign(content: rendered)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4 grid grid-rows-[auto,1fr] ">
      <div class="flex justify-between items-end">
        <h1 class="text-sm text-slate-600 flex gap-0.5 items-center">
          <.link patch={~p"/#{@group_slug}/wiki"} class="opacity-60 hover:underline">wiki</.link>
          <span class="text-xs">/</span>
          <span class="">{@page_title}</span>
        </h1>

        <div class="flex gap-2 ">
          <Components.shortcut key="r">
            <.link href={~p"/#{@group_slug}/wiki/#{@slug}/revisions"} class="btn btn-ghost">
              Revisions
            </.link>
          </Components.shortcut>
          <Components.shortcut key="e">
            <.link href={~p"/#{@group_slug}/wiki/#{@slug}/edit"} class="btn btn-primary">
              Edit
            </.link>
          </Components.shortcut>
        </div>
      </div>

      <div class="grid ">
        <div tabindex="1" class="bg-slate-50 p-4 md:p-8 rounded shadow">
          <div
            :if={@backlinks && length(@backlinks) > 0}
            class="float-right bg-white border p-6 py-5 rounded space-y-2 ml-8 mb-8 max-w-52 overflow-hidden"
          >
            <h2 class="text-xs font-semibold text-slate-500">Backlinks</h2>
            <ul class="text-sm space-y-2">
              <%= for {slug, metadata} <- @backlinks do %>
                <li>
                  <a
                    class="text-blue-600 hover:underline opacity-75 hover:opacity-100 leading-none block"
                    href={~p"/#{@group_slug}/wiki/#{slug}"}
                  >
                    {metadata["title"]}
                  </a>
                </li>
              <% end %>
            </ul>
          </div>
          <Components.prose>
            {raw(@content)}
          </Components.prose>
          <div class="clear-both"></div>
        </div>
      </div>
    </div>
    """
  end
end
