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

    pages_by_slug =
      Wik.Wiki.Page
      |> Ash.Query.filter(group_id == ^current_group.id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.select([:id, :slug, :title, :updated_at])
      |> Ash.read(actor: current_user)
      |> case do
        {:ok, pages} ->
          pages
          |> Enum.reduce(%{}, fn page, acc ->
            case page.slug do
              slug when is_binary(slug) and slug != "" -> Map.put(acc, slug, page)
              _ -> acc
            end
          end)

        {:error, error} ->
          Logger.error("""
          🔴 Failed to read pages for: 
          Group: #{current_group} | id: #{current_group.id}
          User: #{current_user} | id: #{current_user.id}
          Error: #{Exception.format(:error, error)}
          """)

          %{}
      end

    socket =
      socket
      # pages_map is keyed by slug for fast lookup in views/components.
      |> Utils.Ctx.add(:pages_map, pages_by_slug)
      |> Utils.Ctx.add(:pages_tree_map, load_pages_tree(current_group, current_user))

    {:cont, socket}
  end

  defp load_pages_tree(current_group, current_user) do
    Wik.Wiki.PageTree
    |> Ash.Query.filter(group_id == ^current_group.id)
    |> Ash.Query.select([:id, :path, :title, :page_id, :updated_at])
    |> Ash.read(actor: current_user)
    |> case do
      {:ok, trees} ->
        Map.new(trees, fn tree -> {tree.path, tree} end)

      {:error, error} ->
        Logger.error("""
        🔴 Failed to read page tree for:
        Group: #{current_group} | id: #{current_group.id}
        User: #{current_user} | id: #{current_user.id}
        Error: #{Exception.format(:error, error)}
        """)

        %{}
    end
  end
end
