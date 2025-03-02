defmodule WikWeb.Page.Revisions.ShowLive do
  use WikWeb, :live_view

  alias Wik.Page
  alias Wik.Revisions

  @impl true
  def mount(_params, session, socket) do
    user = session["user"] || %{}

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:index, 0)}
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

    resource_path = Page.resource_path(group_slug, slug)
    num_revisions = Revisions.count(resource_path)

    {:noreply,
     socket
     |> assign(group_slug: group_slug)
     |> assign(slug: slug)
     |> assign(group_name: Wik.get_group_name(group_slug))
     |> assign(:backlinks, Page.backlinks(group_slug, slug))
     |> assign(:page_title, page_title)
     |> assign(:content, content)
     |> assign(:num_revisions, num_revisions)}
  end

  @impl true
  def handle_event(event, _params, socket) when event in ["prev", "next"] do
    index =
      case event do
        "prev" -> socket.assigns.index + 1
        "next" -> socket.assigns.index - 1
      end

    num_revisions = socket.assigns.num_revisions
    group_slug = socket.assigns.group_slug
    slug = socket.assigns.slug

    if index < 0 || index == num_revisions do
      {:noreply, socket}
    else
      {metadata, body} = Page.load_revision(group_slug, slug, index)

      {:noreply,
       socket
       |> assign(
         index: index,
         content: Page.render(group_slug, body),
         page_title: metadata["title"]
       )}
    end
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="space-y-4 max-w-screen-md mx-auto">
      <div class="flex justify-between items-end gap-4">
        <h1 class="text-xl text-slate-700 grid gap-2 items-end">
          {@page_title}
        </h1>

        <div class="space-y-2">
          <div class="flex justify-end">
            <div class="revisions badge badge-info">
              Revision <span class="current">{@num_revisions - @index}</span>
              <span class="separator">/</span>
              <span class="total">{@num_revisions}</span>
            </div>
          </div>

          <div class="flex gap-2">
            <Components.shortcut key="b">
              <.link href={~p"/#{@group_slug}/wiki/#{@slug}"} class="btn btn-ghost">
                Back
              </.link>
            </Components.shortcut>
            <Components.shortcut key="p">
              <button phx-click="prev" class="btn btn-primary" disabled={@num_revisions - @index == 1}>
                Prev
              </button>
            </Components.shortcut>
            <Components.shortcut key="n">
              <button phx-click="next" class="btn btn-primary" disabled={@index == 0}>
                Next
              </button>
            </Components.shortcut>
          </div>
        </div>
      </div>

      <div>
        <div tabindex="1" class="bg-slate-50 p-4 md:p-8 rounded shadow">
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
