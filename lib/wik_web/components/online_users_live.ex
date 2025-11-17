defmodule WikWeb.OnlineUsersLive do
  use WikWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket), do: WikWeb.Presence.subscribe()
    socket = socket |> assign(:presences, WikWeb.Presence.list_online_users())
    {:ok, socket}
  end

  def handle_info({WikWeb.Presence, {:join, _presence}}, socket) do
    socket = socket |> assign(:presences, WikWeb.Presence.list_online_users())
    {:noreply, socket}
  end

  def handle_info({WikWeb.Presence, {:leave, _presence}}, socket) do
    socket = socket |> assign(:presences, WikWeb.Presence.list_online_users())
    {:noreply, socket}
  end

  def handle_info({WikWeb.Presence, {:update, %{id: _id, meta: _meta}}}, socket) do
    socket = socket |> assign(:presences, WikWeb.Presence.list_online_users())
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <ul id="online_users" class="space-y-8">
      <li :for={%{id: id, metas: metas} <- @presences} id={id}>
        <div class="font-semibold">
          {List.first(metas).username} <sup>{length(metas)}</sup>
        </div>
        <ul class="pl-4">
          <li :for={meta <- metas}>
            <.link navigate={meta.path}>
              {meta.path}
            </.link>
          </li>
        </ul>
      </li>
    </ul>
    """
  end
end
