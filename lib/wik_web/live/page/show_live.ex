defmodule WikWeb.Page.ShowLive do
  use WikWeb, :live_view

  alias Wik.{Page, Wiki}
  require Logger

  @impl true
  def mount(_params, session, socket) do
    user = session["user"] || %{}

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:group_slug, nil)
     |> assign(:slug, nil)
     |> assign(:group_title, nil)
     |> assign(:content, nil)
     |> assign(:backlinks, [])}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => slug}, _uri, socket) do
    group_title = Wik.get_group_title(group_slug)

    case Page.load(group_slug, slug) do
      {:ok, content} ->
        rendered = Wiki.render(group_slug, content)
        backlinks = Page.backlinks(group_slug, slug)

        {:noreply,
         socket
         |> assign(:group_slug, group_slug)
         |> assign(:slug, slug)
         |> assign(:group_title, group_title)
         |> assign(:content, rendered)
         |> assign(:backlinks, backlinks)}

      :not_found ->
        {:noreply,
         socket
         |> assign(:group_slug, group_slug)
         |> assign(:slug, slug)
         |> assign(:group_title, group_title)
         |> assign(:content, nil)
         |> assign(:backlinks, [])}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-end">
        <h1 class="text-xl text-slate-700">{@slug}</h1>

        <.link
          phx-hook="SetShortcut"
          phx-hook-shortcut-key="e"
          id="button-edit-page"
          href={~p"/#{@group_slug}/wiki/#{@slug}/edit"}
          class="btn btn-primary mt-4"
          title="Ctrl+e"
        >
          Edit
        </.link>
      </div>

      <div>
        <div tabindex="1" class="bg-slate-50 p-4 md:p-8 rounded shadow">
          <div
            :if={@backlinks && length(@backlinks) > 0}
            class="float-right bg-white border p-6 py-5 rounded space-y-2 ml-8 mb-8 max-w-52 overflow-hidden"
          >
            <h2 class="text-xs font-semibold text-slate-500">Backlinks</h2>
            <ul class="text-sm space-y-2">
              <%= for backlink <- @backlinks do %>
                <li>
                  <a
                    class="text-blue-600 hover:underline opacity-75 hover:opacity-100 leading-none block"
                    href={~p"/#{@group_slug}/wiki/#{backlink}"}
                  >
                    {backlink}
                  </a>
                </li>
              <% end %>
            </ul>
          </div>

          <div class="prose prose-sm prose-a:text-blue-600 prose-a:no-underline hover:prose-a:underline prose-headings:text-slate-600">
            {raw(@content)}
          </div>

          <div class="clear-both"></div>
        </div>
      </div>
    </div>
    """
  end
end
