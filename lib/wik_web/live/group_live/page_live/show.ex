defmodule WikWeb.GroupLive.PageLive.Show do
  @moduledoc """
  LiveView for displaying a wiki page.

  Handles viewing wiki pages within a group.
  """
  @env Mix.env()

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias WikWeb.Components.RealtimeToast
  require Logger
  require Ash.Query

  def page_url(group, %Wik.Wiki.PageTree{path: path}), do: page_url(group, path)
  def page_url(group, %{path: path}) when is_binary(path), do: page_url(group, path)

  def page_url(group, path) when is_binary(path) do
    encoded = encode_path(path)
    "/#{group.slug}/wiki/#{encoded}"
  end

  def page_url(_group, _page), do: "#"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer flash={@flash} ctx={@ctx} sidebar?>
      <%= if @not_found? do %>
        <WikWeb.Components.dialog_page_not_found ctx={@ctx} />
      <% else %>
        <div
          class={["pl-8 mx-auto mt-8", "source-visible-#{@source?}"]}
          style={if(@source?, do: "", else: "width: min(75ch, 100%)")}
        >
          <WikWeb.Components.Page.Breadcrumbs.render
            page_id={@page.id}
            page_tree_path={@page_tree_path}
            ctx={@ctx}
            disabled?={@editing?}
          />

          <h1
            class="pagehead-h1 text-3xl mb-8"
            phx-click={JS.toggle() |> JS.toggle(to: ".pagehead-form")}
          >
            {@page_title_input}
          </h1>
          <div
            style="display:none"
            class="pagehead-form"
          >
            <.form
              :if={Ash.can?({@page, :update}, @current_user)}
              class="grid grid-cols-[1fr_auto] gap-2"
              for={:page_tree_title}
              phx-change="page_title_change"
              phx-submit="page_title_apply"
            >
              <input
                type="text"
                name="title"
                autocomplete="off"
                value={Phoenix.HTML.Form.normalize_value("text", @page_title_input)}
                class="text-3xl w-full mb-8 bg-base-300/50 px-1"
              />

              <div class="">
                <button
                  type="submit"
                  class="btn btn-square hover:btn-accent"
                  phx-click={
                    JS.toggle(to: ".pagehead-form")
                    |> JS.toggle(to: ".pagehead-h1")
                  }
                >
                  <.icon name="hero-check" />
                </button>
                <button
                  type="button"
                  class="btn btn-square hover:btn-accent"
                  phx-click={
                    JS.push("page_title_cancel")
                    |> JS.toggle(to: ".pagehead-form")
                    |> JS.toggle(to: ".pagehead-h1")
                  }
                >
                  <.icon name="hero-x-mark" />
                </button>
              </div>
            </.form>
          </div>

          <.live_component
            module={WikWeb.Components.Page.FormMarkdown}
            id={"form-page-#{@page.id}"}
            form_id={"page-form-#{@page.id}"}
            undo_button_id={"editor-undo-#{@page.id}"}
            redo_button_id={"editor-redo-#{@page.id}"}
            exit_after_save?={@exit_after_save?}
            page={@page}
            page_tree_path={@page_tree_path}
            actor={@current_user}
            group={@ctx.current_group}
            editable={@editing?}
            return_to={page_url(@ctx.current_group, @page_tree_path)}
            pages_tree_map={@ctx.pages_tree_map}
          />
        </div>

        <.modal_unsaved_exit {assigns} />
      <% end %>

      <:sidebar :let={drawer_id}>
        <div :if={not @not_found?} class="grid grid-cols-[auto_1fr] w-full">
          <.sidebar_actions {assigns} drawer_id={drawer_id} />

          <div
            inert={@editing?}
            class={["bg-base-300/60 backdrop-blur transition", @editing? and "opacity-50"]}
          >
            <.sidebar_panels {assigns} />
          </div>
        </div>
      </:sidebar>
    </Layouts.drawer>
    """
  end

  def sidebar_actions(assigns) do
    ~H"""
    <% btn_class = [
      "flex aspect-square items-center",
      "tooltip tooltip-left",
      "rounded-none",
      "backdrop-blur"
    ] %>
    <menu>
      <ul class="menu w-full p-0">
        <li class={[@editing? and "hidden", "md:hidden"]}>
          <label for={@drawer_id} class={btn_class} data-tip="sidebar">
            <.icon name="hero-chevron-left-micro" class="is-drawer-open:hidden" />
            <.icon name="hero-chevron-right-micro" class="is-drawer-close:hidden" />
          </label>
        </li>
      </ul>

      <ul class={["menu w-full p-0", @editing? and "bg-accent/50 rounded-bl backdrop-blur"]}>
        <%= if Ash.can?({@page, :update}, @current_user)  do %>
          <% editing_btn_class = btn_class ++ ["tooltip-accent"] %>
          <% editing_btn_class_disabled =
            editing_btn_class ++ ["pointer-events-none text-base-content/40"] %>
          <li>
            <%= if @editing? do %>
              <button
                type="button"
                class={
                  if(@editor_state.synced?, do: editing_btn_class, else: editing_btn_class_disabled)
                }
                data-tip="Finish editing"
                phx-click="attempt_end_editing"
                phx-value-synced={@editor_state.synced?}
                phx-value-has_undo={@editor_state.has_undo?}
                phx-value-has_redo={@editor_state.has_redo?}
              >
                <.icon name="hero-x-mark-micro" class="" />
              </button>
            <% else %>
              <button
                type="button"
                class={[btn_class, "text-base-content/50"]}
                phx-click="toggle_editing"
                data-tip="Edit page"
              >
                <.icon name="hero-pencil-solid" />
              </button>
            <% end %>
          </li>
          <%= if @editing? do %>
            <li>
              <button
                form={"page-form-#{@page.id}"}
                type="submit"
                class={
                  if(@editor_state.synced?, do: editing_btn_class_disabled, else: editing_btn_class)
                }
                data-tip={ "Save as v.#{@page.versions_count + 1}" }
              >
                <.icon name="hero-arrow-down-tray-micro" />
              </button>
            </li>
            <li>
              <button
                id={"editor-undo-#{@page.id}"}
                type="button"
                data-tip="Undo"
                class={
                  if(@editor_state.has_undo?, do: editing_btn_class, else: editing_btn_class_disabled)
                }
              >
                <.icon name="hero-arrow-uturn-left-micro" />
              </button>
            </li>
            <li>
              <button
                id={"editor-redo-#{@page.id}"}
                type="button"
                class={
                  if(@editor_state.has_redo?, do: editing_btn_class, else: editing_btn_class_disabled)
                }
                data-tip="Redo"
              >
                <.icon name="hero-arrow-uturn-right-micro" />
              </button>
            </li>
          <% end %>
        <% end %>
      </ul>

      <ul class={["menu w-full p-0"]}>
        <li>
          <button
            type="button"
            phx-click="toggle_source"
            class={[btn_class, if(@source?, do: "bg-base-content/10", else: "text-base-content/50")]}
            data-tip="source markdown"
          >
            <.icon name="hero-hashtag-micro" />
          </button>
        </li>
      </ul>
    </menu>
    """
  end

  def sidebar_panels(assigns) do
    descendants = build_descendant_tree(assigns.page_tree_path, assigns.ctx.pages_tree_map)
    tree_include_siblings? = true

    tree_nodes =
      build_tree(assigns.page_tree_path, assigns.ctx.pages_tree_map, tree_include_siblings?)

    assigns =
      assigns
      |> assign(:descendants, descendants)
      |> assign(:tree_nodes, tree_nodes)
      |> assign(:tree_visible?, tree_visible?(assigns.page_tree_path, assigns.ctx.pages_tree_map))

    ~H"""
    <.sidebar_panel>
      <ul class="text-sm">
        <li>
          <.link
            navigate={
              WikWeb.GroupLive.PageLive.History.page_url(
                @ctx.current_group,
                @page_tree_path,
                @page.versions_count
              )
            }
            class="group flex opacity-70 hover:opacity-100 transition items-center gap-2"
          >
            <!-- https://icon-sets.iconify.design/akar-icons/history/ -->
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24">
              <path
                fill="none"
                stroke="currentColor"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4.266 16.06a8.92 8.92 0 0 0 3.915 3.978a8.7 8.7 0 0 0 5.471.832a8.8 8.8 0 0 0 4.887-2.64a9.07 9.07 0 0 0 2.388-5.079a9.14 9.14 0 0 0-1.044-5.53a8.9 8.9 0 0 0-4.069-3.815a8.7 8.7 0 0 0-5.5-.608c-1.85.401-3.366 1.313-4.62 2.755c-.151.16-.735.806-1.22 1.781M7.5 8l-3.609.72L3 5m9 4v4l3 2"
              />
            </svg>

            <div class="uppercase tracking-wide text-xs">Version <b>{@page.versions_count}</b></div>

            <.icon
              name="hero-chevron-right-mini "
              class="opacity-40 group-hover:opacity-100 ml-auto"
            />
          </.link>
        </li>
      </ul>
    </.sidebar_panel>

    <.sidebar_panel :if={not Enum.empty?(@backlinks)} title="Backlinks" icon="hero-link-mini">
      <ul class="list-disc list-inside">
        <%= if Enum.empty?(@backlinks) do %>
          <li class="text-sm opacity-70">No backlinks yet.</li>
        <% else %>
          <li :for={backlink <- @backlinks} class="text-sm">
            <% source_path = page_tree_path_for(@ctx, backlink.source_page_id) %>
            <.link
              navigate={page_url(@ctx.current_group, source_path)}
              class="opacity-70 hover:opacity-100 transition"
            >
              {backlink_label(@ctx, backlink)}
            </.link>
          </li>
        <% end %>
      </ul>
    </.sidebar_panel>

    {# <.sidebar_panel :if={@descendants != []} title="Subtree" icon="hero-folder-open"> }
    {#   <.descendants_list nodes={@descendants} ctx={@ctx} /> }
    {# </.sidebar_panel> }

    <.sidebar_panel :if={@tree_visible?} title="Subtree" icon="hero-folder-open">
      <.tree_list nodes={@tree_nodes} ctx={@ctx} current_path={@page_tree_path} />
    </.sidebar_panel>

    <.sidebar_panel :if={@toc != []} title="TOC" icon="hero-book-open">
      <div class="text-xs w-46">
        <div
          :for={item <- @toc}
          class="overflow-hidden text-ellipsis text-nowrap"
          style={ "margin-left: #{( item.level - 1 )/2}rem;" }
        >
          <a class="opacity-70 hover:opacity-100 transition" href={ "##{item.slug}" }>
            {item.title}
          </a>
        </div>
      </div>
    </.sidebar_panel>

    <.sidebar_panel title="Presences" icon="hero-users">
      <WikWeb.Components.OnlineUsers.list presences={@ctx[:presences]} />
    </.sidebar_panel>

    <%= if @env == :dev do %>
      <.sidebar_panel title="Debug" icon="hero-bug-ant" class="opacity-0 hover:opacity-100 transition">
        <div class="font-mono text-xs opacity-70">
          <dd>page path: {@page_tree_path}</dd>
          <div>editing?: {@editing?}</div>
          <div>synced?: {@editor_state.synced?}</div>
          <div>has_undo?: {@editor_state.has_undo?}</div>
          <div>has_redo?: {@editor_state.has_redo?}</div>
          <div>exit_after_save?: {@exit_after_save?}</div>
          <div>show_unsaved_modal?: {@show_unsaved_modal}</div>
        </div>
      </.sidebar_panel>
    <% end %>
    """
  end

  attr :nodes, :list, required: true
  attr :ctx, :map, required: true
  attr :nested?, :boolean, default: false

  def descendants_list(assigns) do
    ~H"""
    <ul class={[
      "list-disc list-inside space-y-1 text-xs",
      @nested? && "ml-4"
    ]}>
      <li :for={node <- @nodes}>
        <.link
          navigate={page_url(@ctx.current_group, node.path)}
          class="opacity-70 hover:opacity-100 transition"
        >
          {node.title}
        </.link>

        <.descendants_list
          :if={node.children != []}
          nodes={node.children}
          ctx={@ctx}
          nested?={true}
        />
      </li>
    </ul>
    """
  end

  attr :nodes, :list, required: true
  attr :ctx, :map, required: true
  attr :current_path, :string, required: true
  attr :nested?, :boolean, default: false

  def tree_list(assigns) do
    ~H"""
    <ul class={[
      "list-disc list-inside space-y-1 text-xs",
      @nested? && "ml-3"
    ]}>
      <li :for={node <- @nodes}>
        <.link
          navigate={page_url(@ctx.current_group, node.path)}
          class={[
            "opacity-70 hover:opacity-100 transition",
            node.path == @current_path && "active font-bold pointer-events-none"
          ]}
        >
          {node.title}
        </.link>

        <.tree_list
          :if={node.children != []}
          nodes={node.children}
          ctx={@ctx}
          current_path={@current_path}
          nested?={true}
        />
      </li>
    </ul>
    """
  end

  attr :class, :string, default: ""
  attr :title, :string, default: nil
  attr :icon, :string, default: nil
  slot :inner_block, required: true

  def sidebar_panel(assigns) do
    ~H"""
    <div class={["p-4 border-b border-base-100", "[&_.menu]:p-0", @class]}>
      <h6 :if={assigns[:title]} class="flex items-center gap-2 mb-2">
        <.icon :if={assigns[:icon]} name={@icon} />
        <span class="uppercase tracking-wide text-xs">
          {@title}
        </span>
      </h6>

      {render_slot(@inner_block)}
    </div>
    """
  end

  defp build_descendant_tree(current_path, pages_tree_map) do
    current_path = current_path || ""
    prefix = current_path <> "/"

    descendants =
      pages_tree_map
      |> Map.keys()
      |> Enum.filter(fn path ->
        is_binary(path) and path != "" and String.starts_with?(path, prefix)
      end)

    descendants
    |> Enum.reduce(%{}, fn path, acc ->
      segments = descendant_segments(current_path, path)
      insert_descendant_node(acc, segments, current_path, pages_tree_map)
    end)
    |> nodes_from_map()
  end

  defp descendant_segments(current_path, path) do
    path
    |> String.replace_prefix(current_path <> "/", "")
    |> String.split("/", trim: true)
  end

  defp insert_descendant_node(nodes, [segment | rest], current_path, pages_tree_map, path \\ []) do
    full_path = path ++ [segment]
    path_value = current_path <> "/" <> Enum.join(full_path, "/")
    tree = Map.get(pages_tree_map, path_value)

    node =
      Map.get(nodes, path_value, %{
        path: path_value,
        title: segment,
        tree: tree,
        children: %{}
      })

    children =
      if rest == [] do
        node.children
      else
        insert_descendant_node(node.children, rest, current_path, pages_tree_map, full_path)
      end

    Map.put(nodes, path_value, %{node | children: children})
  end

  defp nodes_from_map(map) do
    map
    |> Map.values()
    |> Enum.map(fn node ->
      %{node | children: nodes_from_map(node.children)}
    end)
    |> Enum.sort_by(fn node -> String.downcase(node.title || "") end)
  end

  defp build_tree(current_path, pages_tree_map, include_siblings?) do
    current_path = current_path || ""
    root_path = root_path(current_path)

    paths =
      if include_siblings? do
        Map.keys(pages_tree_map)
        |> Enum.filter(fn path ->
          path == root_path or String.starts_with?(path, root_path <> "/")
        end)
      else
        descendant_paths =
          Map.keys(pages_tree_map)
          |> Enum.filter(fn path ->
            path == current_path or String.starts_with?(path, current_path <> "/")
          end)

        (ancestor_paths(current_path) ++ descendant_paths)
        |> Enum.uniq()
      end

    children =
      paths
      |> Enum.reject(&(&1 == root_path))
      |> Enum.reduce(%{}, fn path, acc ->
        segments = descendant_segments(root_path, path)
        insert_descendant_node(acc, segments, root_path, pages_tree_map)
      end)

    root_tree = Map.get(pages_tree_map, root_path)
    root_title = Wik.Wiki.PageTree.Utils.title_from_path(root_path)

    [
      %{
        path: root_path,
        title: root_title,
        tree: root_tree,
        children: nodes_from_map(children)
      }
    ]
  end

  defp tree_visible?(path, pages_tree_map) do
    path = path || ""
    has_parent? = String.contains?(path, "/")

    has_descendants? =
      pages_tree_map
      |> Map.keys()
      |> Enum.any?(fn candidate ->
        String.starts_with?(candidate, path <> "/")
      end)

    has_parent? or has_descendants?
  end

  defp root_path(path) do
    case String.split(path || "", "/", trim: true) do
      [root | _] -> root
      _ -> path || ""
    end
  end

  defp ancestor_paths(path) do
    segments = String.split(path || "", "/", trim: true)

    1..length(segments)
    |> Enum.map(fn count ->
      segments |> Enum.take(count) |> Enum.join("/")
    end)
  end

  def modal_unsaved_exit(assigns) do
    ~H"""
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
    """
  end

  @impl true
  def mount(%{"page_slug_segments" => page_slug_segments}, _session, socket) do
    page_path = page_slug_segments |> Enum.join("/")
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns.current_user
    pages_tree_map = socket.assigns.ctx.pages_tree_map || %{}

    with {:ok, tree, updated_map} <-
           Wik.Wiki.PageTree.Utils.resolve_tree_by_path(
             page_path,
             current_group.id,
             current_user,
             pages_tree_map
           ),
         {:ok, ensured_tree} <- Wik.Wiki.PageTree.Utils.ensure_page_for_tree(tree, current_user),
         {:ok, page} <-
           Wik.Wiki.Page
           |> Ash.get(
             ensured_tree.page_id,
             actor: current_user,
             load: [:versions_count]
           ) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Wik.PubSub, "page:updated:#{page.id}")
        Phoenix.PubSub.subscribe(Wik.PubSub, "page:destroyed:#{page.id}")

        Phoenix.PubSub.subscribe(
          Wik.PubSub,
          Wik.Wiki.PageTree.Utils.pages_tree_topic(current_group.id)
        )
      end

      updated_map = Map.put(updated_map, ensured_tree.path, ensured_tree)

      socket =
        socket
        |> put_pages_tree_maps(updated_map)
        |> Utils.Ctx.add(:page, page)
        |> Utils.Ctx.add(:page_tree, ensured_tree)

      {:ok,
       socket
       |> assign(:env, @env)
       |> assign(:debug?, false)
       |> assign(:not_found?, false)
       |> assign(:page, page)
       |> assign(:page_title, Wik.Wiki.PageTree.Utils.title_from_path(ensured_tree.path))
       |> assign(:page_tree_path, ensured_tree.path)
       |> assign(:page_title_input, Wik.Wiki.PageTree.Utils.title_from_path(ensured_tree.path))
       |> set_editing(false)
       |> assign(:source?, false)
       |> assign(:editor_state, %{synced?: true, has_undo?: false, has_redo?: false})
       |> assign(:show_unsaved_modal, false)
       |> assign(:exit_after_save?, false)
       |> assign(:updated_fields, [])
       |> assign(:backlinks, load_backlinks(page))
       |> assign(:toc, Utils.Markdown.extract_toc(page.text))
       |> maybe_subscribe_backlinks(page)}
    else
      _ ->
        {:ok,
         socket
         |> assign(:env, @env)
         |> assign(:debug?, false)
         |> assign(:not_found?, true)
         |> assign(:page, nil)
         |> assign(:page_title, "Page not found")
         |> assign(:page_tree_path, page_path)
         |> assign(:page_title_input, "")
         |> set_editing(false)
         |> assign(:source?, false)
         |> assign(:editor_state, %{synced?: true, has_undo?: false, has_redo?: false})
         |> assign(:show_unsaved_modal, false)
         |> assign(:exit_after_save?, false)
         |> assign(:updated_fields, [])
         |> assign(:backlinks, [])}
    end
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

    raw_path = title || ""
    pages_tree_map = socket.assigns.ctx.pages_tree_map || %{}

    case Wik.Wiki.PageTree.Utils.resolve_tree_by_path(
           raw_path,
           current_group.id,
           current_user,
           pages_tree_map
         ) do
      {:ok, tree, updated_map} ->
        case Wik.Wiki.PageTree.Utils.ensure_page_for_tree(tree, current_user) do
          {:ok, ensured_tree} ->
            updated_map = Map.put(updated_map, ensured_tree.path, ensured_tree)
            socket = put_pages_tree_maps(socket, updated_map)

            {:reply, %{ok: true, page: %{id: ensured_tree.page_id, path: ensured_tree.path}},
             socket}

          {:error, _} ->
            {:reply, %{ok: false, error: "create_failed"}, socket}
        end

      {:error, _} ->
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

      case rename_page_tree_path(socket, old_path, sanitized) do
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
        {:noreply, refresh_pages_tree(socket)}

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

  defp set_editing(socket, value) do
    socket =
      socket
      |> assign(:editing?, value)
      |> Utils.Ctx.add(:editing?, value)

    if connected?(socket) and socket.assigns[:page] do
      if value do
        push_event(socket, "set_mode", %{mode: "edit"})
      else
        socket = refresh_pages_tree(socket)
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

  defp parse_bool("true", _default), do: true
  defp parse_bool("false", _default), do: false
  defp parse_bool(true, _default), do: true
  defp parse_bool(false, _default), do: false
  defp parse_bool(nil, default), do: default
  defp parse_bool(_, default), do: default

  defp encode_path(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map(&URI.encode/1)
    |> Enum.join("/")
  end

  defp load_backlinks(page) do
    Wik.Wiki.Backlink.Utils.list_for_page(page)
  end

  defp page_tree_path_for(ctx, page_id) do
    case Map.get(ctx.pages_tree_by_page_id || %{}, page_id) do
      %{path: path} when is_binary(path) and path != "" -> path
      _ -> nil
    end
  end

  defp backlink_label(ctx, backlink) do
    path = page_tree_path_for(ctx, backlink.source_page_id)

    cond do
      is_binary(path) and path != "" ->
        path

      is_binary(backlink.target_slug) and backlink.target_slug != "" ->
        backlink.target_slug

      true ->
        "Unknown"
    end
  end

  defp editor_markdown(socket) do
    text = socket.assigns.page.text || ""
    tree_by_id = socket.assigns.ctx.pages_tree_by_id || %{}
    Wik.Wiki.PageTree.Markdown.to_editor(text, tree_by_id)
  end

  defp refresh_pages_tree(socket) do
    group_id = socket.assigns.ctx.current_group.id
    actor = socket.assigns.current_user

    pages_tree_map =
      Wik.Wiki.PageTree
      |> Ash.Query.filter(group_id == ^group_id)
      |> Ash.Query.select([:id, :path, :title, :page_id, :updated_at])
      |> Ash.read(actor: actor)
      |> case do
        {:ok, trees} -> Map.new(trees, fn tree -> {tree.path, tree} end)
        _ -> socket.assigns.ctx.pages_tree_map || %{}
      end

    socket = put_pages_tree_maps(socket, pages_tree_map)

    case page_tree_path_for(socket.assigns.ctx, socket.assigns.page.id) do
      path when is_binary(path) and path != "" ->
        socket
        |> assign(:page_tree_path, path)
        |> assign(:page_title, Wik.Wiki.PageTree.Utils.title_from_path(path))
        |> assign(:page_title_input, Wik.Wiki.PageTree.Utils.title_from_path(path))

      _ ->
        socket
    end
  end

  defp rename_page_tree_path(socket, old_path, new_title) do
    new_title = Wik.Wiki.PageTree.Utils.sanitize_segment(new_title)

    if new_title == "" do
      {:error, :invalid_title}
    else
      new_path = build_renamed_path(old_path, new_title)

      if new_path == old_path do
        {:ok, socket, new_path}
      else
        group_id = socket.assigns.ctx.current_group.id
        actor = socket.assigns.current_user

        case move_subtree(group_id, actor, old_path, new_path) do
          :ok ->
            socket = refresh_pages_tree(socket)
            {:ok, socket, new_path}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defp build_renamed_path(old_path, new_title) do
    segments = String.split(old_path || "", "/", trim: true)

    case Enum.drop(segments, -1) do
      [] -> new_title
      parent_segments -> Enum.join(parent_segments ++ [new_title], "/")
    end
  end

  defp move_subtree(group_id, actor, old_path, new_path) do
    trees =
      Wik.Wiki.PageTree
      |> Ash.Query.filter(group_id == ^group_id)
      |> Ash.Query.select([:id, :path, :group_id])
      |> Ash.read(actor: actor)

    case trees do
      {:ok, items} ->
        {moving, rest} =
          Enum.split_with(items, fn tree ->
            tree.path == old_path or String.starts_with?(tree.path, old_path <> "/")
          end)

        if moving == [] do
          {:error, :not_found}
        else
          updates =
            Enum.map(moving, fn tree ->
              suffix = String.replace_prefix(tree.path, old_path, "")
              {tree, new_path <> suffix}
            end)

          new_paths = MapSet.new(Enum.map(updates, fn {_tree, path} -> path end))
          rest_paths = MapSet.new(Enum.map(rest, & &1.path))

          if MapSet.disjoint?(new_paths, rest_paths) do
            case Wik.Repo.transaction(fn ->
                   Enum.reduce_while(updates, [], fn {tree, path}, notifications ->
                     changeset =
                       Ash.Changeset.for_update(tree, :update, %{path: path}, actor: actor)

                     case Ash.update(changeset,
                            authorize?: false,
                            return_notifications?: true
                          ) do
                       {:ok, _tree, new_notifications} ->
                         {:cont, notifications ++ new_notifications}

                       {:error, reason} ->
                         Wik.Repo.rollback(reason)
                     end
                   end)
                 end) do
              {:ok, notifications} ->
                if notifications != [] do
                  Ash.Notifier.notify(notifications)
                end

                :ok

              {:error, _} ->
                {:error, :update_failed}
            end
          else
            {:error, :conflict}
          end
        end

      {:error, _} ->
        {:error, :load_failed}
    end
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

  defp put_pages_tree_maps(socket, pages_tree_map) do
    pages_tree_by_page_id =
      Enum.reduce(pages_tree_map, %{}, fn {_path, tree}, acc ->
        case tree.page_id do
          page_id when is_binary(page_id) and page_id != "" ->
            Map.put(acc, page_id, tree)

          _ ->
            acc
        end
      end)

    pages_tree_by_id =
      Enum.reduce(pages_tree_map, %{}, fn {_path, tree}, acc ->
        Map.put(acc, tree.id, tree)
      end)

    socket
    |> Utils.Ctx.add(:pages_tree_map, pages_tree_map)
    |> Utils.Ctx.add(:pages_tree_by_page_id, pages_tree_by_page_id)
    |> Utils.Ctx.add(:pages_tree_by_id, pages_tree_by_id)
  end

  defp maybe_subscribe_backlinks(socket, page) do
    if connected?(socket) do
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
      tree_by_id = socket.assigns.ctx.pages_tree_by_id || %{}
      markdown = Wik.Wiki.PageTree.Markdown.to_editor(updated_page.text || "", tree_by_id)
      push_event(socket, "collab_saved_version", %{markdown: markdown})
    else
      socket
    end
  end
end
