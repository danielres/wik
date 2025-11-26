defmodule WikWeb.GroupLive.PageLive.Index do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Pages
        <:actions></:actions>
      </.header>

      <.table
        id="pages"
        rows={@streams.pages}
        row_click={
          fn {_id, page} -> JS.navigate(~p"/#{@ctx.current_group.slug}/pages/#{page.slug}") end
        }
        row_class={
          fn {_id, page} ->
            (page.id in @highlighted_page_ids && "animate-reload") ||
              "hover:bg-base-200 transition"
          end
        }
      >
        <:col :let={{_id, page}} label="Title">{page.title}</:col>
        <:col :let={{_id, page}} label="Slug">{page.slug}</:col>
        <:col :let={{_id, page}} label="Text">{page.text}</:col>

        <:action :let={{id, page}}>
          <.link
            phx-click={JS.push("delete", value: %{id: page.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "page:created")
      Phoenix.PubSub.subscribe(Wik.PubSub, "page:updated")
      Phoenix.PubSub.subscribe(Wik.PubSub, "page:destroyed")
    end

    pages = reload_pages!(socket)

    {:ok,
     socket
     |> assign(:page_title, "Listing Pages")
     |> assign_new(:current_user, fn -> nil end)
     |> assign(:highlighted_page_ids, MapSet.new())
     |> stream(:pages, pages)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  defp reload_pages!(socket) do
    current_group_id = socket.assigns.ctx.current_group.id

    Wik.Wiki.Page
    |> Ash.Query.filter(group_id == ^current_group_id)
    |> Ash.read!(actor: socket.assigns[:current_user])
  end

  defp reload_page!(socket, id) do
    Wik.Wiki.Page |> Ash.get!(id, actor: socket.assigns.current_user)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    page = Ash.get!(Wik.Wiki.Page, id, actor: socket.assigns.current_user)
    Ash.destroy!(page, actor: socket.assigns.current_user)

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "create", payload: payload}, socket) do
    # Only show pages for the current group
    if payload.data.group_id == socket.assigns.ctx.current_group.id do
      Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

      {:noreply,
       socket
       |> stream_insert(:pages, payload.data, at: 0)
       |> update(:highlighted_page_ids, &MapSet.put(&1, payload.data.id))
       |> RealtimeToast.put_create_toast(payload)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    if payload.data.group_id == socket.assigns.ctx.current_group.id do
      socket =
        socket
        |> stream_delete(:pages, payload.data)
        |> RealtimeToast.put_delete_toast(payload)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    # Only show pages for the current group
    if payload.data.group_id == socket.assigns.ctx.current_group.id do
      Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

      socket =
        socket
        |> stream_insert(:pages, reload_page!(socket, payload.data.id))
        |> update(:highlighted_page_ids, &MapSet.put(&1, payload.data.id))
        |> RealtimeToast.put_update_toast(payload)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:clear_highlight, page_id}, socket) do
    page = reload_page!(socket, page_id)

    {:noreply,
     socket
     |> update(:highlighted_page_ids, &MapSet.delete(&1, page_id))
     |> stream_insert(:pages, page)}
  end
end
