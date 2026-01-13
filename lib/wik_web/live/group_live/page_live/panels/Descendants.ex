defmodule WikWeb.GroupLive.PageLive.Panels.Descendants do
  use WikWeb, :html

  def panel(assigns) do
    descendants = build_descendant_tree(assigns.page_tree_path, assigns.ctx.pages_tree_map)
    assigns = assigns |> assign(:descendants, descendants)

    ~H"""
    <.descendants_list
      nodes={build_descendant_tree(@page_tree_path, @ctx.pages_tree_map)}
      ctx={@ctx}
    />
    """
  end

  def build_descendant_tree(current_path, pages_tree_map) do
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

  def nodes_from_map(map) do
    map
    |> Map.values()
    |> Enum.map(fn node ->
      %{node | children: nodes_from_map(node.children)}
    end)
    |> Enum.sort_by(fn node -> String.downcase(node.title || "") end)
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
          navigate={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, node.path)}
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

  def insert_descendant_node(nodes, [segment | rest], current_path, pages_tree_map, path \\ []) do
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

  def descendant_segments(current_path, path) do
    path
    |> String.replace_prefix(current_path <> "/", "")
    |> String.split("/", trim: true)
  end
end
