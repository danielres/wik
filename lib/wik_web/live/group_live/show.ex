defmodule WikWeb.GroupLive.Show do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        <:actions>
          <%= if Ash.can?({@group, :update}, @current_user) do %>
            <.link
              class="btn btn-neutral btn-circle hover:btn-primary"
              patch={~p"/#{@group.slug}/edit"}
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
        phx-click-close={JS.patch(~p"/#{@group.slug}")}
      >
        <.live_component
          module={WikWeb.Components.Group.Form}
          id={ "form-group-#{@group.id}" }
          group={@group}
          actor={@current_user}
          return_to={~p"/#{@group.slug}"}
        >
        </.live_component>
      </.live_component>
      <div class="space-y-4">
        <div class="card bg-base-200 p-4">
          <h2>Author</h2>
          <div>
            {@group.author |> to_string}
          </div>
        </div>

        <div class="card bg-base-200 p-4">
          <h2>Description</h2>
          <div class={[:text in @updated_fields && "animate-reload"]}>
            {@group.text}
          </div>
        </div>

        <div class="card bg-base-200 p-4">
          <h2>Members<sup class="opacity-75 ml-1">{@ctx.current_group.users |> length()}</sup></h2>
          <ul class="list list-disc ml-4">
            <li :for={member <- @ctx.current_group.users}>
              {member |> to_string()}
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    group = reload_group!(slug, socket)

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
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
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
    socket = socket |> push_navigate(to: ~p"/")
    {:noreply, socket}
  end
end
