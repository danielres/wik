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
  def handle_params(%{"group_slug" => group_slug, "slug" => slug}, _uri, socket) do
    {page_title, content} =
      case Page.load(group_slug, slug) do
        {:ok, {metadata, body}} ->
          {metadata["title"], Page.render(group_slug, body)}

        :not_found ->
          {String.capitalize(slug), nil}
      end

    {:noreply,
     socket
     |> assign(group_slug: group_slug)
     |> assign(slug: slug)
     |> assign(group_name: Wik.get_group_name(group_slug))
     |> assign(:backlinks, Page.backlinks(group_slug, slug))
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
        <h1 class="text-xl text-slate-700">{@page_title}</h1>

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

          <div class="prose
            prose-sm
            max-w-none
            prose-a:text-blue-600
            prose-a:no-underline
            hover:prose-a:underline
            prose-headings:text-slate-600
            text-pretty
            prose-headings:text-balance
            [&_strong]:text-slate-600
            [&_h1]:text-2xl [&_h1]:font-normal
            [&_h2]:text-xl [&_h2]:font-normal
            [&_h2]:border-b [&_h2]:border-slate-500/40
            [&_h2]:leading-snug [&_h2]:pb-2
            [&_h3]:text-lg [&_h3]:font-normal
            [&_h4]:text-base
            [&_h5]:text-sm
            [&_h6]:text-xs
          ">
            {raw(@content)}
          </div>

          <div class="clear-both"></div>
        </div>
      </div>
    </div>
    """
  end
end
