defmodule WikWeb.GroupLive.WikimapLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer flash={@flash} ctx={@ctx} backdrop?>
      <:backdrop>
        <div
          id="wikimap-canvas"
          phx-hook="Wikimap"
          phx-update="ignore"
          data-graph={@graph_json}
          data-group-slug={@ctx.current_group.slug}
          class="w-full h-full rounded-lg bg-base-200 border border-base-300"
        >
        </div>
      </:backdrop>

      <Layouts.page_container>
        <:title>
          <div class="w-fit bg-base-200/50 backdrop-blur">Wiki map</div>
        </:title>

        <div class="space-y-4 grid w-fit">
          <div :if={@orphan_pages != []} class="card bg-base-300/20 p-3 backdrop-blur">
            <h3 class="text-xs uppercase tracking-wide opacity-70 mb-2">
              <i class="hero-exclamation-triangle-micro text-yellow-400"></i> Orphan pages
            </h3>

            <ul class="flex flex-wrap gap-2 text-sm">
              <li :for={slug <- @orphan_pages}>
                <.link
                  navigate={"/#{@ctx.current_group.slug}/wiki/#{slug}"}
                  class="px-2 py-1 rounded bg-base-300/60"
                >
                  {slug}
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </Layouts.page_container>
    </Layouts.drawer>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Wiki map")
     |> assign_graph()}
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  defp assign_graph(socket) do
    {graph, orphan_pages} =
      build_graph(socket.assigns.ctx.current_group, socket.assigns.current_user)

    socket
    |> assign(:graph_json, Jason.encode!(graph))
    |> assign(:orphan_pages, orphan_pages)
  end

  defp build_graph(group, actor) do
    pages =
      Wik.Wiki.Page
      |> Ash.Query.filter(group_id == ^group.id)
      |> Ash.Query.load([:backlinks_count])
      |> Ash.Query.select([:id, :slug, :title])
      |> Ash.read!(actor: actor)

    backlinks =
      Wik.Wiki.Backlink
      |> Ash.Query.filter(group_id == ^group.id)
      |> Ash.Query.load([:source_page, :target_page])
      |> Ash.read!(authorize?: false)

    existing_nodes =
      Enum.map(pages, fn page ->
        %{
          id: page.id,
          label: page.title,
          slug: page.slug,
          exists: true,
          backlinks: page.backlinks_count || 0
        }
      end)

    # Keep only edges to existing targets
    backlink_edges =
      backlinks
      |> Enum.filter(&(not is_nil(&1.target_page_id)))
      |> Enum.map(fn bl ->
        %{source: bl.source_page_id, target: bl.target_page_id}
      end)

    parent_edges = build_parent_edges(pages)

    edges =
      backlink_edges
      |> Enum.concat(parent_edges)
      |> Enum.reduce(MapSet.new(), fn %{source: source, target: target}, acc ->
        MapSet.put(acc, {source, target})
      end)
      |> Enum.map(fn {source, target} -> %{source: source, target: target} end)

    # Collect slugs for missing-target backlinks (orphans)
    missing_target_slugs =
      backlinks
      |> Enum.filter(&is_nil(&1.target_page_id))
      |> Enum.map(& &1.target_slug)
      |> Enum.uniq()

    # Degree map for existing pages
    deg =
      edges
      |> Enum.flat_map(fn e -> [e.source, e.target] end)
      |> Enum.reduce(%{}, fn id, acc -> Map.update(acc, id, 1, &(&1 + 1)) end)

    {orphan_nodes, connected_nodes} =
      Enum.split_with(existing_nodes, fn n -> Map.get(deg, n.id, 0) == 0 end)

    orphan_slugs = Enum.map(orphan_nodes, & &1.slug)
    graph_nodes = connected_nodes

    {%{group_slug: group.slug, nodes: graph_nodes, edges: edges},
     orphan_slugs ++ missing_target_slugs}
  end

  defp build_parent_edges(pages) do
    slug_to_id =
      Enum.reduce(pages, %{}, fn page, acc ->
        case page.slug do
          slug when is_binary(slug) and slug != "" -> Map.put(acc, slug, page.id)
          _ -> acc
        end
      end)

    pages
    |> Enum.reduce([], fn page, acc ->
      case page.slug do
        slug when is_binary(slug) and slug != "" ->
          segments = String.split(slug, "/", trim: true)

          if length(segments) > 1 do
            parent_slug = segments |> Enum.drop(-1) |> Enum.join("/")

            case Map.get(slug_to_id, parent_slug) do
              nil -> acc
              parent_id -> [%{source: parent_id, target: page.id} | acc]
            end
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end
end
