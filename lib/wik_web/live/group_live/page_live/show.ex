defmodule WikWeb.GroupLive.PageLive.Show do
  @moduledoc """
  LiveView for displaying a wiki page.

  Handles viewing wiki pages within a group.
  """
  @env Mix.env()

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast
  alias WikWeb.GroupLive.PageLive.Show
  alias WikWeb.GroupLive.PageLive.Panels
  alias WikWeb.Layouts
  require Logger
  require Ash.Query

  def page_url(group, %Wik.Wiki.PageTree{path: path}), do: page_url(group, path)
  def page_url(group, %{path: path}) when is_binary(path), do: page_url(group, path)
  def page_url(group, path) when is_binary(path), do: "/#{group.slug}/wiki/#{encode_path(path)}"

  def page_url(_group, _page), do: "#"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer2 flash={@flash} ctx={@ctx} open?={@open?} panels?>
      <div
        class={["mx-auto mt-8", "source-visible-#{@source?}"]}
        style={if(@source?, do: "", else: "width: min(75ch, 100%)")}
      >
        <div class="relative">
          <WikWeb.Components.Page.Breadcrumbs.render
            ctx={@ctx}
            page_id={@page.id}
            page_tree_path={@page_tree_path}
            disabled?={@editing?}
          />

          <div class="mr-16">
            <Show.PageHead.render page={@page} current_user={@current_user} input={@page_title_input} />
          </div>
        </div>
        <Show.FormMarkdown.render {assigns} />
      </div>

      <Show.ModalUnsavedExit.render {assigns} />

      <:actions>
        <Show.Actions.render {assigns} />
      </:actions>

      <:panels>
        <Layouts.panel title="Presences" icon="hero-users">
          <WikWeb.Components.OnlineUsers.list presences={@ctx[:presences]} />
        </Layouts.panel>

        <Layouts.panel :if={not Enum.empty?(@backlinks)} title="Backlinks" icon="hero-link-mini">
          <Panels.Backlinks.panel ctx={@ctx} backlinks={@backlinks} />
        </Layouts.panel>

        <Layouts.panel
          :if={Panels.Tree.tree_visible?(@page_tree_path, @ctx.pages_tree_map)}
          title="Subtree"
          icon="hero-folder-open"
        >
          <Panels.Tree.panel ctx={@ctx} page_tree_path={@page_tree_path} />
        </Layouts.panel>

        <Layouts.panel :if={@toc != []} title="TOC" icon="hero-book-open">
          <Panels.Toc.panel ctx={@ctx} toc={@toc} />
        </Layouts.panel>

        <Layouts.panel>
          <Panels.Versions.panel ctx={@ctx} page_tree_path={@page_tree_path} page={@page} />
        </Layouts.panel>

        <Layouts.panel
          :if={@env == :dev}
          title="Debug"
          icon="hero-bug-ant"
          class="opacity-0 hover:opacity-100"
        >
          <Panels.Debug.panel {assigns} />
        </Layouts.panel>
      </:panels>

      {# <:panel :if={true || "@descendants != []"} title="Descendants" icon="hero-folder-open"> }
      {#   <Panels.Panels.panel_descendants }
      {#     ctx={@ctx} }
      {#     page_tree_path={@page_tree_path} }
      {#   /> }
      {# </:panel> }
    </Layouts.drawer2>
    """
  end

  @impl true
  def mount(%{"page_slug_segments" => page_slug_segments}, _session, socket) do
    page_path = page_slug_segments |> Enum.join("/")
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns.current_user
    pages_tree_map = socket.assigns.ctx.pages_tree_map || %{}

    with {:ok, page, ensured_tree, updated_map} <-
           load_page_from_path(page_path, current_group, current_user, pages_tree_map) do
      {:ok,
       socket
       |> maybe_subscribe_page(current_group, page)
       |> maybe_subscribe_backlinks(page)
       |> assign_loaded_page(page, ensured_tree, updated_map)}
    end
  end

  @impl true
  def handle_event("toggle_open?", _params, socket) do
    {:noreply, socket |> assign(:open?, not socket.assigns.open?)}
  end

  @impl true
  def handle_event("toggle_editing", _params, socket) do
    {:noreply, set_editing(socket, not socket.assigns.editing?)}
  end

  @impl true
  def handle_event("toggle_source", _params, socket) do
    {:noreply, socket |> assign(:source?, not socket.assigns.source?)}
  end

  @impl true
  def handle_event("attempt_end_editing", params, socket) do
    state = %{
      synced?: Utils.Boolean.parse(params["synced"], socket.assigns.editor_state.synced?),
      has_undo?: Utils.Boolean.parse(params["has_undo"], socket.assigns.editor_state.has_undo?),
      has_redo?: Utils.Boolean.parse(params["has_redo"], socket.assigns.editor_state.has_redo?)
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

    raw_path = title || ""
    pages_tree_map = socket.assigns.ctx.pages_tree_map || %{}

    case resolve_tree_with_page(raw_path, current_group, current_user, pages_tree_map) do
      {:ok, ensured_tree, updated_map} ->
        socket = Show.Utils.PageTree.put_pages_tree_maps(socket, updated_map)

        {:reply, %{ok: true, page: %{id: ensured_tree.page_id, path: ensured_tree.path}}, socket}

      {:error, :ensure, _} ->
        {:reply, %{ok: false, error: "create_failed"}, socket}

      {:error, :resolve, _} ->
        {:reply, %{ok: false, error: "title_required"}, socket}
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
  def handle_event("page_title_change", %{"title" => title}, socket) do
    sanitized = Wik.Wiki.PageTree.Utils.sanitize_segment(title)
    {:noreply, assign(socket, :page_title_input, sanitized)}
  end

  @impl true
  def handle_event("page_title_cancel", _params, socket) do
    title = Wik.Wiki.PageTree.Utils.title_from_path(socket.assigns.page_tree_path)
    {:noreply, assign(socket, :page_title_input, title)}
  end

  @impl true
  def handle_event("page_title_apply", %{"title" => title}, socket) do
    if socket.assigns[:page] do
      sanitized = Wik.Wiki.PageTree.Utils.sanitize_segment(title)
      old_path = socket.assigns.page_tree_path || ""

      case Show.Utils.PageTree.rename_page_tree_path(socket, old_path, sanitized) do
        {:ok, socket, new_path} ->
          {:noreply,
           socket
           |> assign(:page_title_input, Wik.Wiki.PageTree.Utils.title_from_path(new_path))
           |> maybe_reseed_after_rename()
           |> push_patch(to: page_url(socket.assigns.ctx.current_group, new_path))}

        {:error, _reason} ->
          title = Wik.Wiki.PageTree.Utils.title_from_path(old_path)
          {:noreply, assign(socket, :page_title_input, title)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, url, socket) do
    current_path = URI.parse(url).path
    socket = Utils.Ctx.add(socket, :current_path, current_path)
    WikWeb.Presence.track_in_liveview(socket, url)
    socket = socket |> assign(current_path: current_path)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    updated_page = reload_page!(payload.data.id, socket)
    updated_fields = Map.keys(payload.changeset.attributes)

    if updated_fields == [] do
      {:noreply, socket}
    else
      Process.send_after(self(), :clear_updated_fields, 2000)

      socket =
        socket
        |> assign(
          page: updated_page,
          page_title: Wik.Wiki.PageTree.Utils.title_from_path(socket.assigns.page_tree_path),
          updated_fields: updated_fields,
          backlinks: load_backlinks(updated_page)
        )
        |> assign(:toc, Utils.Markdown.extract_toc(updated_page.text))
        |> Utils.Ctx.add(:page, updated_page)
        |> RealtimeToast.put_update_toast(payload)
        |> maybe_push_saved_version(updated_fields, updated_page)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:pages_tree_updated, group_id}, socket) do
    cond do
      group_id != socket.assigns.ctx.current_group.id ->
        {:noreply, socket}

      socket.assigns[:page] ->
        {:noreply, Show.Utils.PageTree.refresh_pages_tree(socket)}

      true ->
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

  defp reload_page!(page_id, socket) do
    Wik.Wiki.Page
    |> Ash.get!(
      page_id,
      actor: socket.assigns.current_user,
      load: [:versions_count]
    )
  end

  defp load_page_from_path(page_path, group, actor, pages_tree_map) do
    with {:ok, ensured_tree, updated_map} <-
           resolve_tree_with_page(page_path, group, actor, pages_tree_map),
         {:ok, page} <-
           Wik.Wiki.Page
           |> Ash.get(ensured_tree.page_id, actor: actor, load: [:versions_count]) do
      {:ok, page, ensured_tree, updated_map}
    end
  end

  defp resolve_tree_with_page(path, group, actor, pages_tree_map) do
    case Wik.Wiki.PageTree.Utils.resolve_tree_by_path(path, group.id, actor, pages_tree_map) do
      {:ok, tree, updated_map} ->
        case Wik.Wiki.PageTree.Utils.ensure_page_for_tree(tree, actor) do
          {:ok, ensured_tree} ->
            {:ok, ensured_tree, Map.put(updated_map, ensured_tree.path, ensured_tree)}

          {:error, reason} ->
            {:error, :ensure, reason}
        end

      {:error, reason} ->
        {:error, :resolve, reason}
    end
  end

  defp maybe_subscribe_page(socket, group, page) do
    if connected?(socket) do
      pages_tree_topic = Wik.Wiki.PageTree.Utils.pages_tree_topic(group.id)
      Phoenix.PubSub.subscribe(Wik.PubSub, pages_tree_topic)
      Phoenix.PubSub.subscribe(Wik.PubSub, "page:updated:#{page.id}")
      Phoenix.PubSub.subscribe(Wik.PubSub, "page:destroyed:#{page.id}")
    end

    socket
  end

  defp assign_loaded_page(socket, page, ensured_tree, updated_map) do
    page_title = Wik.Wiki.PageTree.Utils.title_from_path(ensured_tree.path)

    socket
    |> Show.Utils.PageTree.put_pages_tree_maps(updated_map)
    |> assign(:page, page)
    |> assign(:page_title, page_title)
    |> assign(:page_tree_path, ensured_tree.path)
    |> assign(:page_title_input, page_title)
    |> assign(:open?, false)
    |> assign(:env, @env)
    |> assign(:debug?, false)
    |> assign(:source?, false)
    |> set_editing(false)
    |> assign(:editor_state, %{synced?: true, has_undo?: false, has_redo?: false})
    |> assign(:updated_fields, [])
    |> assign(:show_unsaved_modal, false)
    |> assign(:exit_after_save?, false)
    |> assign(:backlinks, load_backlinks(page))
    |> assign(:toc, Utils.Markdown.extract_toc(page.text))
  end

  defp set_editing(socket, value) do
    socket =
      socket
      |> assign(:editing?, value)
      |> Utils.Ctx.add(:editing?, value)

    if connected?(socket) and socket.assigns[:page] do
      if value do
        push_event(socket, "set_mode", %{mode: "edit"})
      else
        socket = Show.Utils.PageTree.refresh_pages_tree(socket)
        markdown = editor_markdown(socket)

        push_event(socket, "set_mode", %{
          mode: "view",
          markdown: markdown,
          reseed: true
        })
      end
    else
      socket
    end
  end

  defp encode_path(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map(&URI.encode/1)
    |> Enum.join("/")
  end

  defp load_backlinks(page) do
    Wik.Wiki.Backlink.Utils.list_for_page(page)
  end

  defp editor_markdown(socket) do
    text = socket.assigns.page.text || ""
    tree_by_id = socket.assigns.ctx.pages_tree_by_id || %{}
    Wik.Wiki.PageTree.Markdown.to_editor(text, tree_by_id)
  end

  defp maybe_reseed_after_rename(socket) do
    if connected?(socket) and not socket.assigns.editing? do
      markdown = editor_markdown(socket)

      push_event(socket, "set_mode", %{
        mode: "view",
        markdown: markdown,
        reseed: true
      })
    else
      socket
    end
  end

  defp maybe_subscribe_backlinks(socket, page) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wik.PubSub, "backlinks:page:#{page.group_id}:#{page.id}")
    end

    socket
  end

  defp maybe_push_saved_version(socket, updated_fields, updated_page) do
    text_changed? =
      Enum.any?(updated_fields, fn field ->
        to_string(field) == "text"
      end)

    if text_changed? do
      tree_by_id = socket.assigns.ctx.pages_tree_by_id || %{}
      markdown = Wik.Wiki.PageTree.Markdown.to_editor(updated_page.text || "", tree_by_id)
      push_event(socket, "collab_saved_version", %{markdown: markdown})
    else
      socket
    end
  end
end
