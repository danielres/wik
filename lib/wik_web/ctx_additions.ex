defmodule WikWeb.CtxAdditions do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  use WikWeb, :verified_routes
  use WikWeb, :live_view
  require Ash.Query
  require Logger

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {WikWeb.LiveUserAuth, :current_user}

  def on_mount(:ctx_additions, _params, _session, socket) do
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns[:current_user]

    {pages_tree_map, pages_tree_by_page_id, pages_tree_by_id} =
      load_pages_tree_maps(current_group, current_user)

    socket =
      socket
      |> Utils.Ctx.add(:pages_tree_map, pages_tree_map)
      |> Utils.Ctx.add(:pages_tree_by_page_id, pages_tree_by_page_id)
      |> Utils.Ctx.add(:pages_tree_by_id, pages_tree_by_id)

    {:cont, socket}
  end

  defp load_pages_tree_maps(current_group, current_user) do
    Wik.Wiki.PageTree
    |> Ash.Query.filter(group_id == ^current_group.id)
    |> Ash.Query.select([:id, :path, :title, :page_id, :updated_at])
    |> Ash.read(actor: current_user)
    |> case do
      {:ok, trees} ->
        pages_tree_map = Map.new(trees, fn tree -> {tree.path, tree} end)

        pages_tree_by_page_id =
          Enum.reduce(trees, %{}, fn tree, acc ->
            case tree.page_id do
              page_id when is_binary(page_id) and page_id != "" ->
                Map.put(acc, page_id, tree)

              _ ->
                acc
            end
          end)

        pages_tree_by_id = Map.new(trees, fn tree -> {tree.id, tree} end)

        {pages_tree_map, pages_tree_by_page_id, pages_tree_by_id}

      {:error, error} ->
        Logger.error("""
        🔴 Failed to read page tree for:
        Group: #{current_group} | id: #{current_group.id}
        User: #{current_user} | id: #{current_user.id}
        Error: #{Exception.format(:error, error)}
        """)

        {%{}, %{}, %{}}
    end
  end
end
