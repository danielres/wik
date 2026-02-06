defmodule WikWeb.GroupLive.PageLive.History do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  alias Wik.Wiki.PageTree
  require Ash.Query

  def page_url(group, %PageTree{path: path}, version), do: page_url(group, path, version)

  def page_url(group, %{path: path}, version) when is_binary(path),
    do: page_url(group, path, version)

  def page_url(group, path, version) when is_binary(path) do
    encoded = encode_path(path)
    "/#{group.slug}/v/#{version}/wiki/#{encoded}"
  end

  def page_url(_group, _path, _version), do: "#"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer2 flash={@flash} ctx={@ctx} panels?>
      <%= if(@not_found?) do %>
        <WikWeb.Components.dialog_page_not_found ctx={@ctx} />
      <% else %>
        <Layouts.page_container>
          <%= if @version.data["text"] do %>
            <% tree_by_id = @ctx.pages_tree_by_id || %{} %>
            <% text_value =
              PageTree.Markdown.rewrite_wikid_to_wikilinks(@version.data["text"], tree_by_id) %>
            <div
              id={"milkdown-editor-#{@v}"}
              phx-hook="MilkdownEditor"
              phx-update="ignore"
              data-markdown={text_value}
              data-mode="static"
            />
          <% else %>
            <div class="opacity-50">(Empty)</div>
          <% end %>
        </Layouts.page_container>
      <% end %>

      {# FIXME: MIGRATE TO NEW LAYOUT }
      <:sticky_toolbar>
        <div :if={not @not_found?} class="toolbar-editor-controls">
          <div class="space-y-1">
            <div class="flex gap-2 items-start">
              <div>
                <div class="toolbar-actions items-center text-xs">
                  <.link
                    class={["action", @v == 1 and "action-disabled"]}
                    patch={
                      if @v == 1, do: "#", else: page_url(@ctx.current_group, @page_tree_path, 1)
                    }
                    aria-disabled={@v == 1}
                    tabindex={@v == 1 && "-1"}
                  >
                    <.icon name="hero-chevron-double-left-mini" />
                  </.link>
                  <.link
                    class={["action", @v == 1 and "action-disabled"]}
                    patch={
                      if @v > 1, do: page_url(@ctx.current_group, @page_tree_path, @v - 1), else: "#"
                    }
                    aria-disabled={@v == 1}
                    tabindex={@v == 1 && "-1"}
                  >
                    <.icon name="hero-chevron-left-mini" />
                  </.link>
                  <div class="whitespace-nowrap min-w-16 text-center">
                    <span>{@v}</span>
                    <span class="opacity-60">/</span>
                    <span class="opacity-60">{@page.versions_count}</span>
                  </div>
                  <.link
                    patch={
                      if @v < @page.versions_count,
                        do: page_url(@ctx.current_group, @page_tree_path, @v + 1),
                        else: "#"
                    }
                    class={["action", @v == @page.versions_count and "action-disabled"]}
                    aria-disabled={@v == @page.versions_count}
                    tabindex={@v == @page.versions_count && "-1"}
                  >
                    <.icon name="hero-chevron-right-mini" />
                  </.link>
                  <.link
                    patch={page_url(@ctx.current_group, @page_tree_path, @page.versions_count)}
                    class={["action", @v == @page.versions_count and "action-disabled"]}
                    aria-disabled={@v == @page.versions_count}
                    tabindex={@v == @page.versions_count && "-1"}
                  >
                    <.icon name="hero-chevron-double-right-mini" />
                  </.link>
                </div>

                <div class="text-end text-xs px-2 pt-1 opacity-80 hover:opacity-100 transition">
                  <div>
                    <WikWeb.Components.Time.pretty
                      datetime={@version.occurred_at}
                      class="opacity-80 hover:opacity-100 transition"
                    />
                    <span class="opacity-50">by</span>

                    {# TODO: link to author }
                    <.link class="opacity-80 hover:opacity-100 transition">
                      {@author |> to_string()}
                    </.link>
                  </div>
                </div>
              </div>

              <div class="toolbar-actions ">
                <.link
                  class="action !btn-ghost opacity-40 hover:opacity-100 transition"
                  patch={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, @page_tree_path)}
                >
                  <.icon name="hero-x-mark size-6" />
                </.link>
              </div>
            </div>
          </div>
        </div>
      </:sticky_toolbar>
    </Layouts.drawer2>
    """
  end

  def get_page_version(page_id, version_number, actor) do
    require Ash.Query

    Wik.Versions.Version
    |> Ash.Query.filter(record_id == ^page_id and resource == ^Wik.Wiki.Page)
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.Query.offset(version_number - 1)
    |> Ash.Query.limit(1)
    |> Ash.read_one(actor: actor)
  end

  @impl true
  def mount(%{"page_slug_segments" => page_slug_segments}, _session, socket) do
    page_path = page_slug_segments |> Enum.join("/")
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns.current_user
    pages_tree_map = socket.assigns.ctx.pages_tree_map || %{}

    with {:ok, tree, _} <-
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
      {:ok,
       socket
       |> assign(:page, page)
       |> assign(:page_tree_path, ensured_tree.path)
       |> assign(:not_found?, false)
       |> assign(:page_title, Wik.Wiki.PageTree.Utils.title_from_path(ensured_tree.path))}
    else
      _ ->
        {:ok,
         socket
         |> assign(:not_found?, true)
         |> assign(:page, nil)
         |> assign(:page_tree_path, page_path)
         |> assign(:page_title, "Page not found")}
    end
  end

  @impl true
  def handle_params(%{"version" => v}, url, socket) do
    if(socket.assigns.not_found?) do
      {:noreply, socket}
    else
      socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
      WikWeb.Presence.track_in_liveview(socket, url)

      v = v |> String.to_integer()

      case get_page_version(socket.assigns.page.id, v, socket.assigns.current_user) do
        {:ok, version} when not is_nil(version) ->
          author_id = version.user_id
          author = Wik.Accounts.User |> Ash.get(author_id, actor: socket.assigns.current_user)

          socket =
            socket
            |> assign(:version, version)
            |> assign(:v, v)
            |> assign(:author, elem(author, 1) || "Unknown")

          {:noreply, socket}

        _ ->
          {:noreply, assign(socket, :not_found?, true)}
      end
    end
  end

  defp encode_path(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map(&URI.encode/1)
    |> Enum.join("/")
  end
end
