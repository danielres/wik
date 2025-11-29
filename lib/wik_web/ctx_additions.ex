defmodule WikWeb.CtxAdditions do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  import Phoenix.Component
  use WikWeb, :verified_routes
  use WikWeb, :live_view
  require Ash.Query

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {WikWeb.LiveUserAuth, :current_user}

  def on_mount(:ctx_additions, params, _session, socket) do
    current_group_id = socket.assigns.ctx.current_group.id

    pages_map =
      Wik.Wiki.Page
      |> Ash.Query.filter(group_id == ^current_group_id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.select([:id, :title, :slug])
      |> Ash.read!(actor: socket.assigns[:current_user])

    socket =
      socket
      |> ctx_add(:page_slug, params["page_slug"])
      |> ctx_add(:pages_map, pages_map)

    {:cont, socket}
  end

  defp ctx_add(socket, key, value) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)
    ctx = Map.put(socket.assigns.ctx, key, value)
    socket |> assign(ctx: ctx)
  end
end
