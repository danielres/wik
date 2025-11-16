defmodule WikWeb.GroupLive.Index do
  use WikWeb, :live_view
  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
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

      <.table
        id="groups"
        rows={@streams.groups}
        row_click={fn {_id, group} -> JS.navigate(~p"/groups/#{group}") end}
        row_class={
          fn {_id, group} ->
            (group.id in @highlighted_group_ids && "animate-fade-out") || nil
          end
        }
      >
        <:col :let={{_id, group}} label="Title">{group.title}</:col>
        <:col :let={{_id, group}} label="Text">{group.text}</:col>
        <:col :let={{_id, group}} label="Author">{group.author |> to_string}</:col>

        <:action :let={{_id, group}}>
          <.link navigate={~p"/groups/#{group}"}>Show</.link>
        </:action>

        <:action :let={{_id, group}}>
          <%= if Ash.can?({group, :destroy}, @current_user) do %>
            <.link
              phx-click={JS.push("delete", value: %{id: group.id})}
              data-confirm="Are you sure?"
            >
              Delete
            </.link>
          <% end %>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:created")
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:updated")
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:destroyed")
    end

    groups = reload_groups!(socket)

    {:ok,
     socket
     |> assign(:page_title, "Listing Groups")
     |> assign(:highlighted_group_ids, MapSet.new())
     |> assign_new(:current_user, fn -> nil end)
     |> stream(:groups, groups)}
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
     |> put_flash(:info, msg)
     |> update(:highlighted_group_ids, &MapSet.put(&1, payload.data.id))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    msg = ~s(Group "#{payload.data.title}" was just deleted by #{payload.actor})

    {:noreply,
     socket
     |> stream_delete(:groups, payload.data)
     |> put_flash(:info, msg)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    msg = ~s(Group "#{payload.data.title}" was just updated by #{payload.actor})
    Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

    {:noreply,
     socket
     |> stream_insert(:groups, reload_group!(socket, payload.data.id))
     |> update(:highlighted_group_ids, &MapSet.put(&1, payload.data.id))
     |> put_flash(:info, msg)}
  end

  @impl true
  def handle_info({:clear_highlight, group_id}, socket) do
    {:noreply, update(socket, :highlighted_group_ids, &MapSet.delete(&1, group_id))}
  end
end
