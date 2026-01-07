defmodule WikWeb.GroupLive.PageLive.Index do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer flash={@flash} ctx={@ctx}>
      <Layouts.page_container>
        <:title>All pages</:title>

        <div class="grid gap-1" phx-update="stream" id="pages-stream">
          <div
            :for={{id, page} <- @streams.pages}
            id={id}
            class="card rounded bg-base-200/50 space-y-0 px-4 py-2 has-[a.title:hover]:bg-base-300/60 transition"
          >
            <% page_path = page_tree_path_for(@ctx, page.id) %>
            <div class="grid grid-cols-[4fr_2fr_1fr_1fr_1fr_auto] gap-x-8 items-baseline">
              <.link
                navigate={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, page_path)}
                class="title hover:text-white text-sm text-balance break-all"
              >
                {page_path || "Unknown"}
              </.link>

              <div class="justify-self-end">
                <.link
                  class="btn btn-sm opacity-70 hover:opacity-100 transition"
                  patch={
                    WikWeb.GroupLive.PageLive.History.page_url(
                      @ctx.current_group,
                      page_path,
                      page.versions_count
                    )
                  }
                >
                  v. {page.versions_count}
                </.link>
              </div>

              <div class="flex items-center gap-2">
                <i class="hero-clock-micro size-3 opacity-70"></i>
                <WikWeb.Components.Time.pretty
                  datetime={page.updated_at}
                  class="text-xs whitespace-nowrap"
                />
              </div>

              <div class="text-xs text-right tabular-nums">
                <i class="hero-link-solid size-3 opacity-70"></i>
                <span>{page.backlinks_count || 0}</span>
              </div>

              <.link
                phx-click={JS.push("delete", value: %{id: page.id}) |> hide("##{id}")}
                data-confirm="Are you sure?"
                class="opacity-40 hover:opacity-100 transition flex justify-end"
              >
                <i class="hero-trash size-4">
                  delete
                </i>
              </.link>
            </div>
          </div>
        </div>
      </Layouts.page_container>
    </Layouts.drawer>
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
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  defp reload_pages!(socket) do
    current_group_id = socket.assigns.ctx.current_group.id

    Wik.Wiki.Page
    |> Ash.Query.select([:id, :updated_at])
    |> Ash.Query.filter(group_id == ^current_group_id)
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.read!(actor: socket.assigns[:current_user], load: [:versions_count, :backlinks_count])
  end

  defp reload_page!(socket, id) do
    Wik.Wiki.Page
    |> Ash.get!(id, actor: socket.assigns.current_user, load: [:versions_count, :backlinks_count])
  end

  defp page_tree_path_for(ctx, page_id) do
    case Map.get(ctx.pages_tree_by_page_id || %{}, page_id) do
      %{path: path} when is_binary(path) and path != "" -> path
      _ -> nil
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    page = Wik.Wiki.Page |> Ash.get!(id, actor: socket.assigns.current_user)
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
      {:noreply,
       socket
       |> stream_delete(:pages, payload.data)
       |> RealtimeToast.put_delete_toast(payload)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    if payload.data.group_id == socket.assigns.ctx.current_group.id do
      Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

      {:noreply,
       socket
       |> stream_insert(:pages, reload_page!(socket, payload.data.id))
       |> update(:highlighted_page_ids, &MapSet.put(&1, payload.data.id))
       |> RealtimeToast.put_update_toast(payload)}
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
