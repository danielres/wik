defmodule WikWeb.GroupLive.WikitreeLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer flash={@flash} ctx={@ctx} backdrop?>
      <Layouts.page_container>
        <:title>
          <div class="w-fit bg-base-200/50 backdrop-blur">Wiki tree</div>
        </:title>

        <div
          id="wikitree"
          phx-hook="Wikitree"
          phx-update="ignore"
          class="min-h-[60vh]"
          data-graph={@tree_json}
          data-group-slug={@ctx.current_group.slug}
        >
        </div>
      </Layouts.page_container>
    </Layouts.drawer>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      group_id = socket.assigns.ctx.current_group.id
      Phoenix.PubSub.subscribe(Wik.PubSub, Wik.Wiki.PageTree.Utils.pages_tree_topic(group_id))
    end

    {:ok,
     socket
     |> assign(:page_title, "Wiki tree")
     |> assign_tree()}
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "wikitree_move",
        %{"node_path" => node_path, "new_parent_path" => new_parent_path},
        socket
      ) do
    group = socket.assigns.ctx.current_group
    actor = socket.assigns.current_user

    node_path = normalize_path(node_path)
    new_parent_path = normalize_path(new_parent_path)

    with {:ok, leaf} <- leaf_from_path(node_path),
         :ok <- ensure_not_descendant(node_path, new_parent_path),
         new_base_path <- build_new_path(new_parent_path, leaf),
         :ok <- ensure_path_change(node_path, new_base_path),
         :ok <- move_subtree(group.id, actor, node_path, new_base_path) do
      {:reply, %{ok: true}, socket}
    else
      {:error, :no_change} ->
        {:reply, %{ok: true}, socket}

      {:error, reason} ->
        message = move_error_message(reason)
        socket = Toast.put_toast(socket, :error, message)
        {:reply, %{ok: false, error: message}, socket}
    end
  end

  @impl true
  def handle_info({:pages_tree_updated, group_id}, socket) do
    if group_id == socket.assigns.ctx.current_group.id do
      socket = assign_tree(socket)
      {:noreply, push_event(socket, "wikitree_refresh", %{graph: socket.assigns.tree_json})}
    else
      {:noreply, socket}
    end
  end

  defp assign_tree(socket) do
    tree =
      build_tree(socket.assigns.ctx.current_group, socket.assigns.current_user)

    socket
    |> assign(:tree_json, Jason.encode!(tree))
  end

  defp build_tree(group, actor) do
    Wik.Wiki.PageTree
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.select([:path])
    |> Ash.read(actor: actor)
    |> case do
      {:ok, trees} ->
        trees
        |> Enum.reduce(%{}, fn tree, acc ->
          insert_tree_path(acc, tree.path || "")
        end)
        |> nodes_from_map()

      {:error, _} ->
        []
    end
  end

  defp normalize_path(nil), do: ""
  defp normalize_path(path) when is_binary(path), do: String.trim(path)

  defp leaf_from_path(path) do
    case path |> String.split("/", trim: true) |> List.last() do
      nil -> {:error, :invalid_path}
      "" -> {:error, :invalid_path}
      leaf -> {:ok, leaf}
    end
  end

  defp ensure_not_descendant(_node_path, ""), do: :ok

  defp ensure_not_descendant(node_path, new_parent_path) do
    if String.starts_with?(new_parent_path, node_path) do
      {:error, :invalid_target}
    else
      :ok
    end
  end

  defp build_new_path("", leaf), do: leaf
  defp build_new_path(parent_path, leaf), do: parent_path <> "/" <> leaf

  defp ensure_path_change(old_path, new_path) do
    if old_path == new_path do
      {:error, :no_change}
    else
      :ok
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

              {:error, reason} ->
                Logger.error("Failed to move pages_tree subtree: #{inspect(reason)}")
                {:error, :update_failed}
            end
          else
            {:error, :conflict}
          end
        end

      {:error, error} ->
        Logger.error("Failed to load pages_tree: #{inspect(error)}")
        {:error, :load_failed}
    end
  end

  defp move_error_message(:invalid_path), do: "Could not move: invalid path"
  defp move_error_message(:invalid_target), do: "Cannot move a node under itself"
  defp move_error_message(:not_found), do: "Could not move: node not found"
  defp move_error_message(:conflict), do: "Cannot move: target already exists"
  defp move_error_message(:update_failed), do: "Could not move: update failed"
  defp move_error_message(_), do: "Could not move: unexpected error"

  defp insert_tree_path(nodes, path) do
    segments =
      path
      |> String.split("/", trim: true)
      |> Enum.reject(&(&1 == ""))

    insert_segments(nodes, segments)
  end

  defp insert_segments(nodes, []), do: nodes

  defp insert_segments(nodes, [segment | rest]) do
    node =
      Map.get(nodes, segment, %{
        text: segment,
        children: %{}
      })

    children =
      if rest == [] do
        node.children
      else
        insert_segments(node.children, rest)
      end

    Map.put(nodes, segment, %{node | children: children})
  end

  defp nodes_from_map(map) do
    map
    |> Enum.sort_by(fn {segment, _node} -> String.downcase(segment) end)
    |> Enum.map(fn {_segment, node} ->
      children = nodes_from_map(node.children)

      if children == [] do
        %{text: node.text}
      else
        %{text: node.text, children: children}
      end
    end)
  end
end
