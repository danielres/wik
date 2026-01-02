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

  def page_url(group, page) do
    "/#{group.slug}/wiki/#{page.slug}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    {@source?}
    <Layouts.drawer flash={@flash} ctx={@ctx} sidebar?>
      <%= if @not_found? do %>
        <WikWeb.Components.dialog_page_not_found ctx={@ctx} />
      <% else %>
        <div
          class={["pl-8 mx-auto mt-8", "source-visible-#{@source?}"]}
          style={if(@source?, do: "", else: "width: min(75ch, 100%)")}
        >
          <WikWeb.Components.Page.Breadcrumbs.render page={@page} ctx={@ctx} disabled?={@editing?} />

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
            return_to={page_url(@ctx.current_group, @page)}
            pages_map={@ctx.pages_map}
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
          <label for={@drawer_id} class={btn_class}>
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
          >
            <.icon name="hero-hashtag-micro" />
          </button>
        </li>
      </ul>
    </menu>
    """
  end

  def sidebar_panels(assigns) do
    descendants = build_descendant_tree(assigns.page, assigns.ctx.pages_map)
    tree_include_siblings? = true
    tree_nodes = build_tree(assigns.page, assigns.ctx.pages_map, tree_include_siblings?)

    assigns =
      assigns
      |> assign(:descendants, descendants)
      |> assign(:tree_nodes, tree_nodes)
      |> assign(:tree_visible?, tree_visible?(assigns.page, assigns.ctx.pages_map))

    ~H"""
    <.sidebar_panel>
      <ul class="text-sm">
        <li>
          <.link
            navigate={
              WikWeb.GroupLive.PageLive.History.page_url(
                @ctx.current_group,
                @page,
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
            <.link
              navigate={page_url(@ctx.current_group, backlink.source_page)}
              class="opacity-70 hover:opacity-100 transition"
            >
              {backlink.source_page.title || backlink.target_slug}
            </.link>
          </li>
        <% end %>
      </ul>
    </.sidebar_panel>

    {# <.sidebar_panel :if={@descendants != []} title="Subtree" icon="hero-folder-open"> }
    {#   <.descendants_list nodes={@descendants} ctx={@ctx} /> }
    {# </.sidebar_panel> }

    <.sidebar_panel :if={@tree_visible?} title="Subtree" icon="hero-folder-open">
      <.tree_list nodes={@tree_nodes} ctx={@ctx} current_slug={@page.slug} />
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
          <dd>page title: {@page.title}</dd>
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
          navigate={page_url(@ctx.current_group, node.page || %{slug: node.slug})}
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
  attr :current_slug, :string, required: true
  attr :nested?, :boolean, default: false

  def tree_list(assigns) do
    ~H"""
    <ul class={[
      "list-disc list-inside space-y-1 text-xs",
      @nested? && "ml-3"
    ]}>
      <li :for={node <- @nodes}>
        <.link
          navigate={page_url(@ctx.current_group, node.page || %{slug: node.slug})}
          class={[
            "opacity-70 hover:opacity-100 transition",
            node.slug == @current_slug && "active font-bold pointer-events-none"
          ]}
        >
          {node.title}
        </.link>

        <.tree_list
          :if={node.children != []}
          nodes={node.children}
          ctx={@ctx}
          current_slug={@current_slug}
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

  defp build_descendant_tree(page, pages_map) do
    current_slug = page.slug || ""
    prefix = current_slug <> "/"

    descendants =
      pages_map
      |> Map.values()
      |> Enum.filter(fn descendant ->
        slug = descendant.slug
        is_binary(slug) and slug != "" and String.starts_with?(slug, prefix)
      end)

    descendants
    |> Enum.reduce(%{}, fn descendant, acc ->
      segments = descendant_segments(current_slug, descendant.slug)
      insert_descendant_node(acc, segments, current_slug, pages_map)
    end)
    |> nodes_from_map()
  end

  defp descendant_segments(current_slug, slug) do
    slug
    |> String.replace_prefix(current_slug <> "/", "")
    |> String.split("/", trim: true)
  end

  defp insert_descendant_node(nodes, [segment | rest], current_slug, pages_map, path \\ []) do
    full_path = path ++ [segment]
    full_slug = current_slug <> "/" <> Enum.join(full_path, "/")
    page = Map.get(pages_map, full_slug)
    title = descendant_title(page, segment)

    node =
      Map.get(nodes, full_slug, %{
        slug: full_slug,
        title: title,
        page: page,
        children: %{}
      })

    children =
      if rest == [] do
        node.children
      else
        insert_descendant_node(node.children, rest, current_slug, pages_map, full_path)
      end

    Map.put(nodes, full_slug, %{node | children: children})
  end

  defp descendant_title(%{title: title}, _fallback) when is_binary(title) and title != "",
    do: title

  defp descendant_title(_page, fallback), do: fallback

  defp nodes_from_map(map) do
    map
    |> Map.values()
    |> Enum.map(fn node ->
      %{node | children: nodes_from_map(node.children)}
    end)
    |> Enum.sort_by(fn node -> String.downcase(node.title || "") end)
  end

  defp build_tree(page, pages_map, include_siblings?) do
    current_slug = page.slug || ""
    root_slug = root_slug(current_slug)

    slugs =
      if include_siblings? do
        Map.keys(pages_map)
        |> Enum.filter(fn slug ->
          slug == root_slug or String.starts_with?(slug, root_slug <> "/")
        end)
      else
        descendant_slugs =
          Map.keys(pages_map)
          |> Enum.filter(fn slug ->
            slug == current_slug or String.starts_with?(slug, current_slug <> "/")
          end)

        (ancestor_slugs(current_slug) ++ descendant_slugs)
        |> Enum.uniq()
      end

    children =
      slugs
      |> Enum.reject(&(&1 == root_slug))
      |> Enum.reduce(%{}, fn slug, acc ->
        segments = descendant_segments(root_slug, slug)
        insert_descendant_node(acc, segments, root_slug, pages_map)
      end)

    root_page = Map.get(pages_map, root_slug)
    root_title = descendant_title(root_page, root_fallback_title(root_slug))

    [
      %{
        slug: root_slug,
        title: root_title,
        page: root_page,
        children: nodes_from_map(children)
      }
    ]
  end

  defp tree_visible?(page, pages_map) do
    slug = page.slug || ""
    has_parent? = String.contains?(slug, "/")

    has_descendants? =
      pages_map
      |> Map.keys()
      |> Enum.any?(fn candidate ->
        String.starts_with?(candidate, slug <> "/")
      end)

    has_parent? or has_descendants?
  end

  defp root_slug(slug) do
    case String.split(slug || "", "/", trim: true) do
      [root | _] -> root
      _ -> slug || ""
    end
  end

  defp ancestor_slugs(slug) do
    segments = String.split(slug || "", "/", trim: true)

    1..length(segments)
    |> Enum.map(fn count ->
      segments |> Enum.take(count) |> Enum.join("/")
    end)
  end

  defp root_fallback_title(slug) do
    slug
    |> String.split("/", trim: true)
    |> List.last()
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
    page_slug = page_slug_segments |> Enum.join("/")
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
         |> assign(:not_found?, false)
         |> assign(:page_title, page.title)
         |> set_editing(false)
         |> assign(:source?, false)
         |> assign(:editor_state, %{synced?: true, has_undo?: false, has_redo?: false})
         |> assign(:show_unsaved_modal, false)
         |> assign(:exit_after_save?, false)
         |> assign(:page, page)
         |> assign(:updated_fields, [])
         |> assign(:backlinks, load_backlinks(page))
         |> assign(:toc, Utils.Markdown.extract_toc(page.text))
         |> maybe_subscribe_backlinks(page)}

      {:error, _error} ->
        {:ok,
         socket
         |> assign(:env, @env)
         |> assign(:debug?, false)
         |> assign(:not_found?, true)
         |> assign(:page_title, "Page not found")
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

    raw_title = title || ""
    normalized_path = normalize_wikilink_title(raw_title)

    case build_wikilink_segments(normalized_path) do
      {:error, :title_required} ->
        {:reply, %{ok: false, error: "title_required"}, socket}

      {:ok, segments} ->
        case ensure_wikilink_pages(current_group, current_user, segments) do
          {:ok, page} ->
            {:reply, %{ok: true, page: %{id: page.id, slug: page.slug, title: page.title}},
             socket}

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
    current_path = URI.parse(url).path
    socket = Utils.Ctx.add(socket, :current_path, current_path)
    WikWeb.Presence.track_in_liveview(socket, url)
    socket = socket |> assign(current_path: current_path)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: payload}, socket) do
    old_slug = socket.assigns.page.slug
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
        |> assign(:toc, Utils.Markdown.extract_toc(updated_page.text))
        |> Utils.Ctx.add(:page, updated_page)
        |> RealtimeToast.put_update_toast(payload)
        |> maybe_push_saved_version(updated_fields, updated_page)

      socket =
        if updated_page.slug != old_slug do
          push_patch(socket, to: page_url(socket.assigns.ctx.current_group, updated_page))
        else
          socket
        end

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

  defp normalize_wikilink_title(title) do
    title
    |> String.split("/", trim: false)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&Utils.String.titleize/1)
    |> Enum.join("/")
  end

  defp build_wikilink_segments(normalized_path) do
    segments = normalized_path |> String.split("/", trim: true)

    if segments == [] do
      {:error, :title_required}
    else
      pairs =
        Enum.map(segments, fn segment ->
          {segment, Utils.Slugify.generate(segment)}
        end)

      if Enum.any?(pairs, fn {_title, slug} -> slug == "" end) do
        {:error, :title_required}
      else
        {:ok, pairs}
      end
    end
  end

  defp ensure_wikilink_pages(current_group, current_user, segments) do
    result =
      Wik.Repo.transaction(fn ->
        Enum.reduce(segments, {nil, ""}, fn {title, slug_segment}, {_page, prefix} ->
          slug = if prefix == "", do: slug_segment, else: prefix <> "/" <> slug_segment

          case get_or_create_page_by_slug(current_group, current_user, slug, title) do
            {:ok, page} -> {page, slug}
            {:error, reason} -> Wik.Repo.rollback(reason)
          end
        end)
      end)

    case result do
      {:ok, {page, _}} -> {:ok, page}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_or_create_page_by_slug(current_group, current_user, slug, title) do
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
          |> Ash.Changeset.change_attribute(:slug, slug)
          |> Ash.create()
        else
          {:error, :lookup_failed}
        end

      {:error, reason} ->
        Logger.error("🔴 Failed to lookup: #{inspect(reason)}")
        {:error, :lookup_failed}
    end
  end

  defp load_backlinks(page) do
    Wik.Wiki.Backlink.Utils.list_for_page(page)
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
      push_event(socket, "collab_saved_version", %{markdown: updated_page.text || ""})
    else
      socket
    end
  end
end
