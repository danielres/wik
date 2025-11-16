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
          <.button variant="primary" navigate={~p"/groups/#{@group}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit Group
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@group.id}</:item>

        <:item title="Title" class={:title in @updated_fields && "animate-fade-out"}>
          {@group.title}
        </:item>

        <:item title="Text" class={:text in @updated_fields && "animate-fade-out"}>
          {@group.text}
        </:item>

        <:item title="Author">{@group.author_id}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    group = reload_group(id, socket)

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

  defp reload_group(group_id, socket) do
    Ash.get!(Wik.Accounts.Group, group_id, actor: socket.assigns.current_user)
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    updated_group = reload_group(payload.data.id, socket)
    updated_fields = Map.keys(payload.changeset.attributes)

    if(updated_fields == []) do
      {:noreply, socket}
    else
      Process.send_after(self(), :clear_updated_fields, 2000)

      socket =
        socket
        |> put_flash(:info, "#{payload.actor.email} just updated this group")
        |> assign(:group, updated_group)
        |> assign(:updated_fields, updated_fields)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_updated_fields, socket) do
    {:noreply, assign(socket, :updated_fields, [])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    title = payload.data.title
    email = payload.actor.email

    {:noreply,
     socket
     |> put_flash(:info, ~s(Group "#{title}" was just deleted by #{email}))
     |> push_navigate(to: ~p"/groups")}
  end
end
