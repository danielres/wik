defmodule WikWeb.EventLive.Show do
  use WikWeb, :live_view
  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Event {@event.id}
        <:subtitle>This is a event record from your database.</:subtitle>
      </.header>

      <.list>
        <:item title="Id">{@event.id}</:item>
        <:item title="Record">{@event.record_id}</:item>
        <:item title="Version">{@event.version}</:item>
        <:item title="Metadata">{inspect(@event.metadata)}</:item>
        <:item title="Data">{inspect(@event.data)}</:item>
        <:item title="Changed attributes">{inspect(@event.changed_attributes)}</:item>
        <:item title="Occurred at">{@event.occurred_at}</:item>
        <:item title="Resource">{@event.resource}</:item>
        <:item title="Action">{@event.action}</:item>
        <:item title="Action type">{@event.action_type}</:item>
        <:item title="User">{@event.user_id}</:item>
      </.list>

      <:aside>
        {live_render(@socket, WikWeb.OnlineUsersLive, id: "online-users")}
      </:aside>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Event")
     |> assign(:event, Ash.get!(Wik.Events.Event, id, actor: socket.assigns.current_user))}
  end

  @impl true
  def handle_params(_params, url, socket) do
    path = URI.parse(url).path

    if connected?(socket),
      do: WikWeb.Presence.track_in_liveview(socket.assigns.current_user, path)

    {:noreply, socket}
  end
end
