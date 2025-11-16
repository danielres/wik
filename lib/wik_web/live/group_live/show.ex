defmodule WikWeb.GroupLive.Show do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Group {@group.id}
        <:subtitle>This is a group record from your database.</:subtitle>

        <:actions>
          <.button navigate={~p"/groups"}>
            <.icon name="hero-arrow-left" />
          </.button>

          <%= if Ash.can?({@group, :update}, @current_user) do %>
            <.button variant="primary" patch={~p"/groups/#{@group}/edit"}>
              <.icon name="hero-pencil-square" /> Edit Group
            </.button>
          <% end %>
        </:actions>
      </.header>

      <.live_component
        module={WikWeb.Components.Generic.Modal}
        mandatory?
        id="user-tz-selector-modal"
        open?={@live_action == :edit}
        phx-click-close={JS.patch(~p"/groups/#{@group.id}")}
      >
        <.live_component
          module={WikWeb.Components.Group.Form}
          id={ "form-group-#{@group.id}" }
          group={@group}
          actor={@current_user}
          return_to={~p"/groups/#{@group.id}"}
        >
        </.live_component>
      </.live_component>

      <.list>
        <:item title="Id">{@group.id}</:item>

        <:item title="Title" class={:title in @updated_fields && "animate-fade-out"}>
          {@group.title}
        </:item>

        <:item title="Text" class={:text in @updated_fields && "animate-fade-out"}>
          {@group.text}
        </:item>

        <:item title="Author">{@group.author |> to_string}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    group = reload_group!(id, socket)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:updated:#{group.id}")
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:destroyed:#{group.id}")
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Group")
     |> assign(:updated_fields, [])
     |> assign(:group, group)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp reload_group!(group_id, socket) do
    Ash.get!(Wik.Accounts.Group, group_id, actor: socket.assigns.current_user, load: [:author])
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    updated_group = reload_group!(payload.data.id, socket)
    updated_fields = Map.keys(payload.changeset.attributes)

    if(updated_fields == []) do
      {:noreply, socket}
    else
      Process.send_after(self(), :clear_updated_fields, 2000)
      msg = "#{payload.actor} just updated this group"
      actor_is_current_user = payload.actor == socket.assigns.current_user
      socket = if actor_is_current_user, do: socket, else: socket |> put_flash(:info, msg)
      socket = socket |> assign(group: updated_group, updated_fields: updated_fields)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_updated_fields, socket) do
    {:noreply, assign(socket, :updated_fields, [])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    msg = ~s(Group "#{payload.data}" was just deleted by #{payload.actor})
    actor_is_current_user = payload.actor == socket.assigns.current_user
    socket = if actor_is_current_user, do: socket, else: socket |> put_flash(:info, msg)
    socket = socket |> push_navigate(to: ~p"/groups")
    {:noreply, socket}
  end
end
