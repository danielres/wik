defmodule WikWeb.GroupLive.PageLive.Show do
  @moduledoc """
  LiveView for displaying a wiki page.

  Handles viewing wiki pages within a group, automatically creating pages
  that don't exist yet when accessed.
  """

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Toast

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        <div class={[:title in @updated_fields && "animate-reload"]}>
          {@page.title}
        </div>

        <:subtitle>
          <.link
            patch={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/v/#{@page.versions_count}"}
            class="btn btn-sm btn-neutral text-base-content/50"
          >
            v. {@page.versions_count}
          </.link>
        </:subtitle>

        <:actions>
          <WikWeb.Components.ButtonEdit.button
            :if={Ash.can?({@page, :update}, @current_user)}
            link={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/edit?return_to=show"}
            watch_path={@current_path <> "/edit"}
            presences={@ctx.presences}
          />
        </:actions>
      </.header>

      <.live_component
        module={WikWeb.Components.Generic.Modal}
        mandatory?
        id={ "modal-form-page-#{@page.id}" }
        open?={@live_action == :edit and connected?(@socket)}
        phx-click-close={JS.patch(~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}")}
      >
        <.live_component
          module={WikWeb.Components.Page.Form}
          id={ "form-page-#{@page.id}" }
          page={@page}
          actor={@current_user}
          group={@ctx.current_group}
          return_to={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}"}
        >
        </.live_component>
      </.live_component>
      <main class={[:text in @updated_fields && "animate-reload"]}>
        {@page.text}
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"page_slug" => page_slug}, _session, socket) do
    case Wik.Wiki.Page
         |> Ash.get(
           %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
           actor: socket.assigns.current_user,
           load: [:versions_count]
         ) do
      {:ok, page} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Wik.PubSub, "page:updated:#{page.id}")
          Phoenix.PubSub.subscribe(Wik.PubSub, "page:destroyed:#{page.id}")
        end

        {:ok,
         socket
         |> assign(:page_title, page.title)
         |> assign(:page, page)
         |> assign(:updated_fields, [])}

      {:error, _error} ->
        page =
          Wik.Wiki.Page
          |> Ash.Changeset.for_create(
            :create,
            %{title: page_slug},
            actor: socket.assigns.current_user,
            context: %{shared: %{current_group_id: socket.assigns.ctx.current_group.id}}
          )
          |> Ash.create!()

        {:ok,
         socket
         |> push_navigate(to: ~p"/#{socket.assigns.ctx.current_group.slug}/pages/#{page.slug}")}
    end
  end

  @impl true
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
    current_path = URI.parse(url).path
    socket = socket |> assign(current_path: current_path)

    socket =
      if socket.assigns.live_action == :edit and has_editors?(socket, current_path) do
        redirect_from_edit(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    updated_page = reload_page!(payload.data.slug, socket)
    updated_fields = Map.keys(payload.changeset.attributes)

    if updated_fields == [] do
      {:noreply, socket}
    else
      Process.send_after(self(), :clear_updated_fields, 2000)
      msg = "Just updated by #{payload.actor}"
      socket = socket |> put_flash(:info, msg)

      socket =
        socket
        |> assign(
          page: updated_page,
          page_title: updated_page.title,
          updated_fields: updated_fields
        )

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_updated_fields, socket) do
    {:noreply, assign(socket, :updated_fields, [])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy", payload: payload}, socket) do
    msg = ~s(Page "#{payload.data.title}" was just deleted by #{payload.actor})
    socket = socket |> Toast.put_toast(:info, msg)
    socket = socket |> push_navigate(to: ~p"/#{socket.assigns.ctx.current_group.slug}/pages")
    {:noreply, socket}
  end

  defp reload_page!(page_slug, socket) do
    Wik.Wiki.Page
    |> Ash.get!(
      %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
      actor: socket.assigns.current_user,
      load: [:versions_count]
    )
  end

  defp has_editors?(socket, path) do
    socket.assigns.ctx.presences
    |> WikWeb.Presence.users_at_path(path)
    |> length() > 0
  end

  defp redirect_from_edit(socket) do
    group_slug = socket.assigns.ctx.current_group.slug
    page_slug = socket.assigns.page.slug

    current_editor =
      socket.assigns.ctx.presences
      |> WikWeb.Presence.users_at_path(socket.assigns.current_path)
      |> List.first()

    socket
    |> push_patch(to: ~p"/#{group_slug}/pages/#{page_slug}")
    |> Toast.put_toast(
      :info,
      "Aready being edited by #{current_editor}, please try again later."
    )
  end
end
