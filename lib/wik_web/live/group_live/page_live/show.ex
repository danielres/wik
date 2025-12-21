defmodule WikWeb.GroupLive.PageLive.Show do
  @moduledoc """
  LiveView for displaying a wiki page.

  Handles viewing wiki pages within a group, automatically creating pages
  that don't exist yet when accessed.
  """
  @env Mix.env()

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <:sticky_toolbar>
        <div class="toolbar-editor-controls">
          <%= if Ash.can?({@page, :update}, @current_user)  do %>
            <div class={["toolbar-actions", not @editing? and "opacity-0"]}>
              <button
                id={"editor-undo-#{@page.id}"}
                type="button"
                class={[
                  "action",
                  if(@editing? and @editor_state.has_undo?,
                    do: "action-enabled",
                    else: "action-disabled"
                  )
                ]}
              >
                <.icon name="hero-arrow-uturn-left-micro" />
              </button>
              <button
                id={"editor-redo-#{@page.id}"}
                type="button"
                class={[
                  "action",
                  if(@editing? and @editor_state.has_redo?,
                    do: "action-enabled",
                    else: "action-disabled"
                  )
                ]}
              >
                <.icon name="hero-arrow-uturn-right-micro" />
              </button>

              <WikWeb.Components.tooltip position="bottom">
                <button
                  form={"page-form-#{@page.id}"}
                  type="submit"
                  class={[
                    "action",
                    if(@editing? and not @editor_state.synced?,
                      do: "action-enabled",
                      else: "action-disabled"
                    )
                  ]}
                >
                  <.icon name="hero-arrow-down-tray-micro" />
                </button>
                <:content>
                  <span class="text-xs">
                    Save as <span class="font-bold">v.{@page.versions_count + 1}</span>
                  </span>
                </:content>
              </WikWeb.Components.tooltip>
            </div>
          <% end %>

          <div class="toolbar-actions">
            <%= if Ash.can?({@page, :update}, @current_user)  do %>
              <WikWeb.Components.tooltip position="left">
                <button
                  :if={not @editing?}
                  type="button"
                  class={["action", "action-enabled"]}
                  phx-click="toggle_editing"
                >
                  <.icon name="hero-lock-closed-micro" />
                </button>
                <:content><span class="text-xs">Unlock to edit</span></:content>
              </WikWeb.Components.tooltip>
              <button
                :if={@editing?}
                type="button"
                class={["action", "action-enabled"]}
                phx-click="attempt_end_editing"
                phx-value-synced={@editor_state.synced?}
                phx-value-has_undo={@editor_state.has_undo?}
                phx-value-has_redo={@editor_state.has_redo?}
              >
                <.icon name="hero-lock-open-micro" />
              </button>
            <% end %>

            <.link
              class={[
                "action action-version",
                if(@editing?, do: "action-disabled", else: "action-enabled")
              ]}
              id={"page-version-link-#{@page.id}"}
              patch={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}/v/#{@page.versions_count}"}
            >
              v.{@page.versions_count}
            </.link>
          </div>
        </div>

        <div
          :if={@env == :dev}
          class={[
            "toolbar-editor-controls ml-auto mt-2",
            not @debug? and "opacity-0 hover:opacity-100"
          ]}
        >
          <div class="toolbar-actions w-fit">
            <.button type="button" class="action" phx-click="toggle_debug">
              <.icon name="hero-bug-ant" />
            </.button>
          </div>
        </div>
        <div
          :if={@env == :dev and @debug?}
          class="bg-base-300 w-fit ml-auto text-xs font-mono mt-2 p-4 rounded-lg"
        >
          <dd>page title: {@ctx.page.title}</dd>
          <div>editing?: {@editing?}</div>
          <div>synced?: {@editor_state.synced?}</div>
          <div>has_undo?: {@editor_state.has_undo?}</div>
          <div>has_redo?: {@editor_state.has_redo?}</div>
          <div>exit_after_save?: {@exit_after_save?}</div>
          <div>show_unsaved_modal?:{@show_unsaved_modal}</div>
        </div>
      </:sticky_toolbar>

      <.live_component
        module={WikWeb.Components.Page.FormMarkdown}
        id={"form-page-#{@page.id}"}
        form_id={"page-form-#{@page.id}"}
        undo_button_id={"editor-undo-#{@page.id}"}
        redo_button_id={"editor-redo-#{@page.id}"}
        exit_after_save?={@exit_after_save?}
        page={@page}
        actor={@current_user}
        group={@ctx.current_group}
        editable={@editing?}
        return_to={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}"}
        pages_map={@ctx.pages_map}
      />

      <.live_component
        module={WikWeb.Components.Generic.Modal}
        id="unsaved-exit-modal"
        open?={@show_unsaved_modal}
        mandatory?={false}
        padding_class="p-4 space-y-4"
        phx-click-close="cancel_exit_modal"
      >
        <div class="space-y-4">
          <div class="text-lg font-semibold">Unsaved changes</div>
          <p class="text-sm opacity-80">
            You have edits that haven&apos;t been saved. What do you want to do?
          </p>

          <div class="flex flex-col gap-2">
            <button
              type="button"
              class="btn btn-sm btn-primary w-full"
              phx-click="save_version_and_continue"
            >
              Save version and continue
            </button>

            <button
              type="button"
              class="btn btn-sm btn-error w-full"
              phx-click="discard_and_continue"
            >
              Forget changes and continue
            </button>
          </div>
        </div>
      </.live_component>

      <:backlinks>
        <div class="space-y-2">
          <div class="flex items-center gap-2">
            <i class="hero-link-mini size-4"></i>
            <span class="uppercase tracking-wide text-xs opacity-70">Backlinks</span>
          </div>

          <ul class="list-disc list-inside">
            <%= if Enum.empty?(@backlinks) do %>
              <li class="text-sm opacity-70">No backlinks yet.</li>
            <% else %>
              <li :for={backlink <- @backlinks} class="text-xs">
                <.link
                  navigate={~p"/#{@ctx.current_group.slug}/wiki/#{backlink.source_page.slug}"}
                  class="hover:text-white"
                >
                  {backlink.source_page.title || backlink.target_slug}
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      </:backlinks>
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
         |> assign(:env, @env)
         |> assign(:debug?, false)
         |> assign(:page_title, page.title)
         |> set_editing(false)
         |> assign(:editor_state, %{synced?: true, has_undo?: false, has_redo?: false})
         |> assign(:show_unsaved_modal, false)
         |> assign(:exit_after_save?, false)
         |> assign(:page, page)
         |> assign(:updated_fields, [])
         |> assign(:backlinks, load_backlinks(page))
         |> maybe_subscribe_backlinks(page)}

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

        redirect_url = page_url(current_group, page)
        {:ok, socket |> push_navigate(to: redirect_url)}
    end
  end

  @impl true
  def handle_event("toggle_editing", _params, socket) do
    {:noreply, set_editing(socket, not socket.assigns.editing?)}
  end

  @impl true
  def handle_event("toggle_debug", _params, socket) do
    {:noreply, socket |> assign(:debug?, !socket.assigns.debug?)}
  end

  @impl true
  def handle_event("attempt_end_editing", params, socket) do
    state = %{
      synced?: parse_bool(params["synced"], socket.assigns.editor_state.synced?),
      has_undo?: parse_bool(params["has_undo"], socket.assigns.editor_state.has_undo?),
      has_redo?: parse_bool(params["has_redo"], socket.assigns.editor_state.has_redo?)
    }

    if state.synced? do
      {:noreply, set_editing(socket, false)}
    else
      {:noreply, assign(socket, show_unsaved_modal: true, editor_state: state)}
    end
  end

  @impl true
  def handle_event("save_version_and_continue", _params, socket) do
    form_id = "page-form-#{socket.assigns.page.id}"

    {:noreply,
     socket
     |> assign(:exit_after_save?, true)
     |> push_event("submit_page_form", %{form_id: form_id})}
  end

  @impl true
  def handle_event("discard_and_continue", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_unsaved_modal, true)
     |> push_event("revert_to_saved", %{})}
  end

  @impl true
  def handle_event("cancel_exit_modal", _params, socket) do
    {:noreply, assign(socket, show_unsaved_modal: false, exit_after_save?: false)}
  end

  @impl true
  def handle_event("wikilink_create", %{"title" => title}, socket) do
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns.current_user

    title = (title || "") |> String.trim()

    if title == "" do
      {:reply, %{ok: false, error: "title_required"}, socket}
    else
      slug = Wik.Wiki.Page.Utils.canonical_slug(title)

      page_result =
        case Wik.Wiki.Page
             |> Ash.get(
               %{group_id: current_group.id, slug: slug},
               actor: current_user
             ) do
          {:ok, page} ->
            {:ok, page}

          {:error, %Ash.Error.Invalid{errors: errors}} when is_list(errors) ->
            if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
              Wik.Wiki.Page
              |> Ash.Changeset.for_create(
                :create,
                %{title: title, text: ""},
                actor: current_user,
                context: %{shared: %{current_group_id: current_group.id}}
              )
              |> Ash.create()
            else
              {:error, :lookup_failed}
            end

          {:error, reason} ->
            Logger.error("🔴 Failed to lookup", error: inspect(reason))
            {:error, :lookup_failed}
        end

      case page_result do
        {:ok, page} ->
          {:reply, %{ok: true, page: %{id: page.id, slug: page.slug, title: page.title}}, socket}

        {:error, :lookup_failed} ->
          {:reply, %{ok: false, error: "lookup_failed"}, socket}

        {:error, _} ->
          {:reply, %{ok: false, error: "create_failed"}, socket}
      end
    end
  end

  @impl true
  def handle_event("editor_state", params, socket) do
    state = %{
      synced?: Map.get(params, "synced?", true),
      has_undo?: Map.get(params, "has_undo?", false),
      has_redo?: Map.get(params, "has_redo?", false)
    }

    {:noreply, assign(socket, editor_state: state)}
  end

  @impl true
  def handle_event("revert_done", _params, socket) do
    socket =
      socket
      |> assign(:show_unsaved_modal, false)
      |> assign(:exit_after_save?, false)
      |> set_editing(false)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
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
          updated_fields: updated_fields,
          backlinks: load_backlinks(updated_page)
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

  @impl true
  def handle_info(:backlinks_updated, socket) do
    {:noreply, assign(socket, :backlinks, load_backlinks(socket.assigns.page))}
  end

  def handle_info({:page_saved_for_exit, _page_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_unsaved_modal, false)
     |> assign(:exit_after_save?, false)
     |> set_editing(false)}
  end

  defp reload_page!(page_slug, socket) do
    Wik.Wiki.Page
    |> Ash.get!(
      %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
      actor: socket.assigns.current_user,
      load: [:versions_count]
    )
  end

  defp set_editing(socket, value) do
    socket =
      socket
      |> assign(:editing?, value)
      |> Utils.Ctx.add(:editing?, value)

    if connected?(socket) do
      push_event(socket, "set_editable", %{editable: value})
    else
      socket
    end
  end

  defp parse_bool("true", _default), do: true
  defp parse_bool("false", _default), do: false
  defp parse_bool(true, _default), do: true
  defp parse_bool(false, _default), do: false
  defp parse_bool(nil, default), do: default
  defp parse_bool(_, default), do: default

  defp load_backlinks(page) do
    Wik.Wiki.Backlink.Utils.list_for_page(page)
  end

  defp maybe_subscribe_backlinks(socket, page) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "backlinks:slug:#{page.group_id}:#{page.slug}")
      Phoenix.PubSub.subscribe(Wik.PubSub, "backlinks:page:#{page.group_id}:#{page.id}")
    end

    socket
  end

  # defp has_editors?(socket, path) do
  #   socket.assigns.ctx.presences
  #   |> WikWeb.Presence.users_at_path(path)
  #   |> length() > 0
  # end

  # defp redirect_from_edit(socket) do
  #   group_slug = socket.assigns.ctx.current_group.slug
  #   page_slug = socket.assigns.page.slug
  #
  #   current_editor =
  #     socket.assigns.ctx.presences
  #     |> WikWeb.Presence.users_at_path(socket.assigns.current_path)
  #     |> List.first()
  #
  #   socket
  #   |> push_patch(to: ~p"/#{group_slug}/wiki/#{page_slug}")
  #   |> Toast.put_toast(
  #     :info,
  #     "Aready being edited by #{current_editor}, please try again later."
  #   )
  # end

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
