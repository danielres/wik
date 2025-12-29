defmodule WikWeb.GroupLive.Show do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer flash={@flash} ctx={@ctx}>
      <Layouts.page_container>
        <:title>
          <div class="flex items-center justify-between">
            {@group.title}
            <WikWeb.Components.ButtonEdit.button
              :if={Ash.can?({@group, :update}, @current_user)}
              link={~p"/#{@group.slug}/edit"}
              watch_path={@current_path <> "/edit"}
              presences={@ctx.presences}
            />
          </div>
        </:title>
        <:subtitle>
          Group details
        </:subtitle>

        <.live_component
          module={WikWeb.Components.Generic.Modal}
          mandatory?
          id={ "modal-form-group-#{@group.id}" }
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

        <% heading_class = "font-bold" %>
        <% content_class = "opacity-70 text-sm" %>

        <div class="space-y-4">
          <div class="card bg-base-200 p-4 space-y-2">
            <h2 class={heading_class}>
              Created by
            </h2>
            <div class={content_class}>
              {@group.author |> to_string}
            </div>
          </div>

          <div class="card bg-base-200 p-4 space-y-2">
            <h2 class={heading_class}>
              Description
            </h2>
            <div class={[:text in @updated_fields && "animate-reload", content_class]}>
              {@group.text || "(no description)"}
            </div>
          </div>

          <div class="card bg-base-200 p-4 space-y-2">
            <h2 class={heading_class}>
              Members<sup class="opacity-75 ml-1">{@group.users |> length()}</sup>
            </h2>
            <ul class={[content_class, "list list-disc ml-4"]}>
              <li :for={member <- @group.users}>
                {member |> to_string()}
              </li>
            </ul>
          </div>

          <div class="card bg-base-200 p-4 space-y-2">
            <div class="flex justify-between">
              <h2 class={heading_class}>
                Pages
              </h2>

              <div>
                <.link
                  class="indicator btn btn-xs btn-neutral opacity-60 hover:opacity-100 transition"
                  navigate={~p"/#{@ctx.current_group.slug}/map"}
                >
                  Map
                </.link>

                <.link
                  class="indicator btn btn-xs btn-neutral opacity-60 hover:opacity-100 transition"
                  navigate={~p"/#{@ctx.current_group.slug}/wiki"}
                >
                  All pages
                  <span class="indicator-item badge badge-neutral border text-base-content/70 rounded-full text-xs p-0 aspect-square">
                    {@group.pages_count}
                  </span>
                </.link>
              </div>
            </div>

            <h3 class={[heading_class, "text-sm opacity-60"]}>
              Recently updated
            </h3>

            <div>
              <.link
                :for={p <- @group.last_updated_pages}
                class={[content_class, "grid grid-cols-3 hover:opacity-100"]}
                navigate={WikWeb.GroupLive.PageLive.Show.page_url(@group, p)}
              >
                <div>{p.title}</div>
                <div>
                  <WikWeb.Components.Time.pretty datetime={p.updated_at} />
                </div>
                <div><span class="opacity-50">by</span> {p.author |> to_string}</div>
              </.link>
            </div>
          </div>
        </div>
      </Layouts.page_container>
    </Layouts.drawer>
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
    socket =
      socket
      |> Utils.Ctx.add(:current_path, URI.parse(url).path)
      |> assign(current_path: URI.parse(url).path)

    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  defp reload_group!(slug, socket) do
    Wik.Accounts.Group
    |> Ash.get!(%{slug: slug},
      actor: socket.assigns.current_user,
      load: [:author, :pages_count, :users, last_updated_pages: [limit: 10]]
    )
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    updated_group = reload_group!(payload.data.slug, socket)
    updated_fields = Map.keys(payload.changeset.attributes)

    if(updated_fields == []) do
      {:noreply, socket}
    else
      Process.send_after(self(), :clear_updated_fields, 2000)

      socket =
        socket
        |> assign(group: updated_group, updated_fields: updated_fields)
        |> RealtimeToast.put_update_toast(payload)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_updated_fields, socket) do
    {:noreply, assign(socket, :updated_fields, [])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    socket =
      socket
      |> RealtimeToast.put_delete_toast(payload)
      |> push_navigate(to: ~p"/")

    {:noreply, socket}
  end
end
