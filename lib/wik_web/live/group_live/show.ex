defmodule WikWeb.GroupLive.Show do
  use WikWeb, :live_view
  on_mount({WikWeb.LiveUserAuth, :live_user_required})

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        <.link class="opacity-50 hover:opacity-100 transition" navigate={~p"/groups"}>
          <.icon name="hero-arrow-left" />
        </.link>
        <div class={:title in @updated_fields && "animate-reload"}>
          {@group.title}
        </div>
        <:subtitle>Group by {@group.author |> to_string}</:subtitle>

        <:actions>
          <%= if Ash.can?({@group, :update}, @current_user) do %>
            <.link
              class="btn btn-neutral btn-circle hover:btn-primary"
              patch={~p"/groups/#{@group.slug}/edit"}
            >
              <.icon name="hero-pencil-square" />
            </.link>
          <% end %>
        </:actions>
      </.header>

      <.live_component
        module={WikWeb.Components.Generic.Modal}
        mandatory?
        id="user-tz-selector-modal"
        open?={@live_action == :edit}
        phx-click-close={JS.patch(~p"/groups/#{@group.slug}")}
      >
        <.live_component
          module={WikWeb.Components.Group.Form}
          id={ "form-group-#{@group.id}" }
          group={@group}
          actor={@current_user}
          return_to={~p"/groups/#{@group.slug}"}
        >
        </.live_component>
      </.live_component>

      <div class={[
        "border-l-4 border-base-content/30 pl-4",
        :text in @updated_fields && "animate-reload"
      ]}>
        {@group.text}
      </div>

      <:aside>
        {live_render(@socket, WikWeb.OnlineUsersLive, id: "online-users")}
      </:aside>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    group = reload_group!(slug, socket)
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:updated:#{group.id}")
      Phoenix.PubSub.subscribe(Wik.PubSub, "group:destroyed:#{group.id}")
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Group")
     |> assign(:updated_fields, [])
     # TODO: assign ctx in live_user_required
     |> assign(:ctx, %{current_user: current_user})
     |> assign(:group, group)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    path = URI.parse(url).path

    if connected?(socket),
      do: WikWeb.Presence.track_in_liveview(socket.assigns.current_user, path)

    {:noreply, socket}
  end

  defp reload_group!(slug, socket) do
    Wik.Accounts.Group
    |> Ash.get!(%{slug: slug}, actor: socket.assigns.current_user, load: [:author])
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    updated_group = reload_group!(payload.data.slug, socket)
    updated_fields = Map.keys(payload.changeset.attributes)

    if(updated_fields == []) do
      {:noreply, socket}
    else
      Process.send_after(self(), :clear_updated_fields, 2000)
      msg = "#{payload.actor} just updated this group"
      actor_is_current_user = payload.actor == socket.assigns.current_user

      socket =
        if actor_is_current_user, do: socket, else: socket |> Toast.put_toast(:success, msg)

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
    socket = if actor_is_current_user, do: socket, else: socket |> Toast.put_toast(:info, msg)
    socket = socket |> push_navigate(to: ~p"/groups")
    {:noreply, socket}
  end
end
