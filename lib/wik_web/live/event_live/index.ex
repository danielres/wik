defmodule WikWeb.EventLive.Index do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Listing versions
      </.header>

      <.table
        id="events"
        rows={@streams.events}
        row_click={
          fn {_id, event} -> JS.navigate(~p"/#{@ctx.current_group.slug}/versions/#{event}") end
        }
      >
        {# <:col :let={{_id, event}} label="Id">{event.id}</:col> }
        {# <:col :let={{_id, event}} label="Record">{event.record_id}</:col> }
        {# <:col :let={{_id, event}} label="Version">{event.version}</:col> }
        {# <:col :let={{_id, event}} label="Metadata">{inspect(event.metadata)}</:col> }
        <:col :let={{_id, event}} label="Data">{inspect(event.data)}</:col>
        <:col :let={{_id, event}} label="Changed attributes">
          {inspect(event.changed_attributes)}
        </:col>
        <:col :let={{_id, event}} label="Occurred at">{event.occurred_at}</:col>
        <:col :let={{_id, event}} label="Resource">{event.resource}</:col>
        <:col :let={{_id, event}} label="Action">{event.action}</:col>
        <:col :let={{_id, event}} label="Action type">{event.action_type}</:col>
        <:col :let={{_id, event}} label="User">{event.user_id}</:col>

        <:action :let={{_id, event}}>
          <div class="sr-only">
            <.link navigate={~p"/#{@ctx.current_group.slug}/versions/#{event}"}>Show</.link>
          </div>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Wik.PubSub, "event:created")

    {:ok,
     socket
     |> assign(:page_title, "Listing Events")
     |> stream(:events, Ash.read!(Wik.Events.Event, actor: socket.assigns[:current_user]))}
  end

  @impl true
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end
end
