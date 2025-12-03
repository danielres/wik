defmodule WikWeb.HomeLive do
  @moduledoc """
  LiveView for the home page showing a user's groups.

  Displays all groups the current user belongs to and allows creating new groups.
  Includes real-time updates when groups are created, updated, or deleted.
  """

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Hi, {@current_user |> to_string}
      </.header>

      <section>
        <h1 class="flex justify-between text-lg font-semibold">
          Your groups
          <div>
            <%= if Ash.can?({Wik.Accounts.Group, :create}, @current_user) do %>
              <.link class="btn btn-neutral btn-circle hover:btn-primary" navigate={~p"/new-group"}>
                <.icon name="hero-plus" />
              </.link>
            <% end %>
          </div>
        </h1>

        <.live_component
          module={WikWeb.Components.Generic.Modal}
          mandatory?
          id="modal-form-group-new"
          open?={@live_action == :new}
          phx-click-close={JS.patch(~p"/")}
        >
          <.live_component
            module={WikWeb.Components.Group.Form}
            id="form-group-new"
            group={nil}
            actor={@current_user}
            return_to={~p"/"}
          >
          </.live_component>
        </.live_component>

        <.table
          id="groups"
          rows={@streams.groups}
          row_click={fn {_id, group} -> JS.navigate(~p"/#{group.slug}/wiki/Home") end}
          row_class={
            fn {_id, group} ->
              (group.id in @highlighted_group_ids && "animate-reload") ||
                "hover:bg-base-200 transition"
            end
          }
        >
          <:col :let={{_id, group}} label="Title">{group.title}</:col>
          <:col :let={{_id, group}} label="Slug">{group.slug}</:col>
          <:col :let={{_id, group}} label="Text">{group.text}</:col>
          <:col :let={{_id, group}} label="Author">{group.author |> to_string}</:col>

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
      </section>
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
     |> assign(:page_title, "Your groups")
     |> assign(:highlighted_group_ids, MapSet.new())
     |> stream(:groups, groups)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  @spec reload_groups!(Phoenix.LiveView.Socket.t()) :: list(Wik.Accounts.Group.t())
  defp reload_groups!(socket) do
    Wik.Accounts.Group |> Ash.read!(actor: socket.assigns[:current_user], load: [:author])
  end

  @spec reload_group!(Phoenix.LiveView.Socket.t(), String.t()) :: Wik.Accounts.Group.t()
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
    Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

    {:noreply,
     socket
     |> stream_insert(:groups, payload.data, at: 0)
     |> update(:highlighted_group_ids, &MapSet.put(&1, payload.data.id))
     |> RealtimeToast.put_create_toast(payload)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    socket =
      socket
      |> stream_delete(:groups, payload.data)
      |> RealtimeToast.put_delete_toast(payload)

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    Process.send_after(self(), {:clear_highlight, payload.data.id}, 2000)

    socket =
      socket
      |> stream_insert(:groups, reload_group!(socket, payload.data.id))
      |> update(:highlighted_group_ids, &MapSet.put(&1, payload.data.id))
      |> RealtimeToast.put_update_toast(payload)

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
