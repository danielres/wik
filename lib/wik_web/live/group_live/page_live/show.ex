defmodule WikWeb.GroupLive.PageLive.Show do
  @moduledoc """
  LiveView for displaying a wiki page.

  Handles viewing wiki pages within a group, automatically creating pages
  that don't exist yet when accessed.
  """

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast

  @impl true
  def render(assigns) do
    ~H"""
    <% editable = @live_action == :edit and connected?(@socket) %>

    <Layouts.app flash={@flash} ctx={@ctx}>
      <div class="flex justify-between mb-16">
        <div class="flex items-center">
          <.link
            class="btn btn-sm opacity-70 hover:opacity-100 transition"
            patch={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}/v/#{@page.versions_count}"}
          >
            v. {@page.versions_count}
          </.link>

          <%= if editable do %>
            <div class="tooltip tooltip-right">
              <div class="tooltip-content">
                <span
                  class="text-xs opacity-80"
                  id={"collab-status-label-#{@page.id}"}
                >
                  Synced
                </span>
              </div>
              <button class="btn btn-sm btn-ghost bg-transparent">
                <span
                  id={"collab-status-dot-#{@page.id}"}
                  class="size-2 rounded-full bg-emerald-500"
                >
                </span>
              </button>
            </div>
          <% end %>
        </div>

        <%= if Ash.can?({@page, :update}, @current_user) and !editable do %>
          <WikWeb.Components.ButtonEdit.button
            link={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}/edit?return_to=show"}
            watch_path={@current_path <> "/edit"}
            presences={@ctx.presences}
          />
        <% end %>

        <%= if editable do %>
          <div class="flex items-center gap-2">
            <a
              id={"collab-done-#{@page.id}"}
              data-done-target
              class="btn btn-sm btn-circle btn-ghost opacity-50 hover:opacity-100 transition "
              href={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}"}
            >
              <i class="hero-arrow-left-micro size-5">Back</i>
            </a>
            <.button
              form={"page-form-#{@page.id}"}
              phx-disable-with="Saving Version..."
              variant="primary"
              data-status-button-save
              class=""
            >
              Save
            </.button>
          </div>
        <% end %>
      </div>

      <.live_component
        module={WikWeb.Components.Page.FormMarkdown}
        id={"form-page-#{@page.id}-#{@page.versions_count}-#{@live_action}"}
        form_id={"page-form-#{@page.id}"}
        status_dot_id={"collab-status-dot-#{@page.id}"}
        status_label_id={"collab-status-label-#{@page.id}"}
        page={@page}
        actor={@current_user}
        group={@ctx.current_group}
        editable={editable}
        return_to={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}"}
        pages_map={@ctx.pages_map}
      />
    </Layouts.app>
    """
  end

  def page_url(group, page) do
    ~p"/#{group.slug}/wiki/#{page.slug}"
  end

  @impl true
  def mount(%{"page_slug" => page_slug}, _session, socket) do
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns.current_user

    case Wik.Wiki.Page
         |> Ash.get(
           %{group_id: current_group.id, slug: page_slug},
           actor: current_user,
           load: [:versions_count]
         ) do
      {:ok, page} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Wik.PubSub, "page:updated:#{page.id}")
          Phoenix.PubSub.subscribe(Wik.PubSub, "page:destroyed:#{page.id}")
        end

        socket = socket |> Utils.Ctx.add(:page, page)

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
            actor: current_user,
            context: %{shared: %{current_group_id: current_group.id}}
          )
          |> Ash.create!()

        redirect_url =
          if Ash.can?({page, :update}, socket.assigns.current_user) do
            page_url(current_group, page) <> "/edit"
          else
            page_url(current_group, page)
          end

        {:ok,
         socket
         |> push_navigate(to: redirect_url)}
    end
  end

  @impl true
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
    current_path = URI.parse(url).path
    socket = socket |> assign(current_path: current_path)

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

      socket =
        socket
        |> assign(
          page: updated_page,
          page_title: updated_page.title,
          updated_fields: updated_fields
        )
        |> RealtimeToast.put_update_toast(payload)
        |> maybe_push_saved_version(updated_fields, updated_page)

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
      |> push_navigate(to: ~p"/#{socket.assigns.ctx.current_group.slug}/wiki")

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
    |> push_patch(to: ~p"/#{group_slug}/wiki/#{page_slug}")
    |> Toast.put_toast(
      :info,
      "Aready being edited by #{current_editor}, please try again later."
    )
  end

  defp maybe_push_saved_version(socket, updated_fields, updated_page) do
    text_changed? =
      Enum.any?(updated_fields, fn field ->
        to_string(field) == "text"
      end)

    if text_changed? do
      push_event(socket, "collab_saved_version", %{markdown: updated_page.text || ""})
    else
      socket
    end
  end
end
