defmodule WikWeb.GroupLive.Index do
  use WikWeb, :live_view
  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Listing Groups
        <:actions>
          <%= if Ash.can?({Wik.Accounts.Group, :create}, @current_user) do %>
            <.button variant="primary" navigate={~p"/groups/new"}>
              <.icon name="hero-plus" /> New Group
            </.button>
          <% end %>
        </:actions>
      </.header>

      <.live_component
        module={WikWeb.Components.Generic.Modal}
        mandatory?
        id="user-tz-selector-modal"
        open?={@live_action == :new}
        phx-click-close={JS.patch(~p"/groups")}
      >
        <.live_component
          module={WikWeb.Components.Group.Form}
          id="form-group-new"
          group={nil}
          actor={@current_user}
          return_to={~p"/groups"}
        >
        </.live_component>
      </.live_component>

      <.table
        id="groups"
        rows={@streams.groups}
        row_click={fn {_id, group} -> JS.navigate(~p"/groups/#{group}") end}
        row_class={
          fn {_id, group} ->
            (group.id in @highlighted_group_ids && "animate-fade-out") ||
              "hover:bg-base-200 transition"
          end
        }
      >
        <:col :let={{_id, group}} label="Title">{group.title}</:col>
        <:col :let={{_id, group}} label="Text">{group.text}</:col>
        <:col :let={{_id, group}} label="Author">{group.author |> to_string}</:col>

        {# <:action :let={{_id, group}}> }
        {#   <.link navigate={~p"/groups/#{group}"}>Show</.link> }
        {# </:action> }

        <:action :let={{_id, group}}>
          <%= if Ash.can?({group, :destroy}, @current_user) do %>
            <.link
              phx-click={JS.push("delete", value: %{id: group.id})}
              data-confirm="Are you sure?"
            >
              <.icon name="hero-trash" />
            </.link>
          <% end %>
        </:action>
      </.table>

      <:aside>
        {live_render(@socket, WikWeb.OnlineUsersLive, id: "online-users")}
      </:aside>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:created")
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:updated")
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:destroyed")
      path = "/groups#{(socket.assigns.live_action == :new && "/new") || ""}"
      WikWeb.Presence.track_in_liveview(current_user, path, "groups_index")
    end

    groups = reload_groups!(socket)

    {:ok,
     socket
     |> assign(:page_title, "Listing Groups")
     |> assign(:highlighted_group_ids, MapSet.new())
     |> assign(:ctx, %{current_user: current_user})
     |> stream(:groups, groups)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp reload_groups!(socket) do
    Wik.Accounts.Group |> Ash.read!(actor: socket.assigns[:current_user], load: [:author])
  end

  defp reload_group!(socket, id) do
    Wik.Accounts.Group |> Ash.get!(id, actor: socket.assigns.current_user, load: [:author])
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    group = Ash.get!(Wik.Accounts.Group, id, actor: socket.assigns.current_user)
    Ash.destroy!(group, actor: socket.assigns.current_user)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "create", payload: payload}, socket) do
    msg = ~s(Group "#{payload.data.title}" was just created by #{payload.actor})
    Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

    {:noreply,
     socket
     |> stream_insert(:groups, payload.data, at: 0)
     |> Toast.put_toast(:info, msg)
     |> update(:highlighted_group_ids, &MapSet.put(&1, payload.data.id))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    actor_is_current_user = payload.actor == socket.assigns.current_user

    socket =
      if actor_is_current_user do
        msg = ~s(Group "#{payload.data}" deleted successfully)
        socket |> Toast.put_toast(:success, msg)
      else
        msg = ~s(Group "#{payload.data}" was just deleted by #{payload.actor})
        socket |> Toast.put_toast(:info, msg)
      end

    socket = socket |> stream_delete(:groups, payload.data)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

    actor_is_current_user = payload.actor == socket.assigns.current_user

    msg =
      if actor_is_current_user,
        do: ~s(Group "#{payload.data}" updated),
        else: ~s(Group "#{payload.data}" was just updated by #{payload.actor})

    socket =
      socket
      |> stream_insert(:groups, reload_group!(socket, payload.data.id))
      |> update(:highlighted_group_ids, &MapSet.put(&1, payload.data.id))
      |> Toast.put_toast(:info, msg)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_highlight, group_id}, socket) do
    group = reload_group!(socket, group_id)

    {:noreply,
     socket
     |> update(:highlighted_group_ids, &MapSet.delete(&1, group_id))
     |> stream_insert(:groups, group)}
  end
end
