defmodule WikWeb.GroupLive.PageLive.Show.Utils.PageTree do
  require Ash.Query
  use WikWeb, :live_view

  def rename_page_tree_path(socket, old_path, new_title) do
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

  def put_pages_tree_maps(socket, pages_tree_map) do
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

  def refresh_pages_tree(socket) do
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

    case WikWeb.GroupLive.PageLive.Panels.Backlinks.page_tree_path_for(
           socket.assigns.ctx,
           socket.assigns.page.id
         ) do
      path when is_binary(path) and path != "" ->
        socket
        |> assign(:page_tree_path, path)
        |> assign(:page_title, Wik.Wiki.PageTree.Utils.title_from_path(path))
        |> assign(:page_title_input, Wik.Wiki.PageTree.Utils.title_from_path(path))

      _ ->
        socket
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
end
