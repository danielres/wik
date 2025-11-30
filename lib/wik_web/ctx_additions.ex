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

    pages_map =
      Wik.Wiki.Page
      |> Ash.Query.filter(group_id == ^current_group.id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.select([:id, :title, :slug, :updated_at])
      |> Ash.read(actor: current_user)
      |> case do
        {:ok, pages} ->
          pages

        {:error, error} ->
          Logger.error("""
          🔴 Failed to read pages for: 
          Group: #{current_group} | id: #{current_group.id}
          User: #{current_user} | id: #{current_user.id}
          Error: #{Exception.format(:error, error)}
          """)

          []
      end

    socket =
      socket
      |> Utils.Ctx.add(:pages_map, pages_map)

    {:cont, socket}
  end
end
