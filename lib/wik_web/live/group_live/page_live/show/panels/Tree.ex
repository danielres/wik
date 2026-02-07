defmodule WikWeb.GroupLive.PageLive.Panels.Tree do
  use WikWeb, :html
  alias WikWeb.GroupLive.PageLive.Panels.Descendants

  def panel(assigns) do
    descendants =
      Descendants.build_descendant_tree(
        assigns.page_tree_path,
        assigns.ctx.pages_tree_map
      )

    tree_include_siblings? = true

    tree_nodes =
      build_tree(assigns.page_tree_path, assigns.ctx.pages_tree_map, tree_include_siblings?)

    assigns =
      assigns
      |> assign(:descendants, descendants)
      |> assign(:tree_nodes, tree_nodes)
      |> assign(:tree_visible?, tree_visible?(assigns.page_tree_path, assigns.ctx.pages_tree_map))

    ~H"""
    <.tree_list nodes={@tree_nodes} ctx={@ctx} current_path={@page_tree_path} />
    """
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
        segments = Descendants.descendant_segments(root_path, path)

        Descendants.insert_descendant_node(
          acc,
          segments,
          root_path,
          pages_tree_map
        )
      end)

    root_tree = Map.get(pages_tree_map, root_path)
    root_title = Wik.Wiki.PageTree.Utils.title_from_path(root_path)

    [
      %{
        path: root_path,
        title: root_title,
        tree: root_tree,
        children: Descendants.nodes_from_map(children)
      }
    ]
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

  def tree_visible?(path, pages_tree_map) do
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

  # TODO: extract to separate component
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
          navigate={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, node.path)}
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
end
