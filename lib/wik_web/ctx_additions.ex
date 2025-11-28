defmodule WikWeb.CtxAdditions do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  import Phoenix.Component
  import Phoenix.LiveView, only: [connected?: 1]
  use WikWeb, :verified_routes
  use WikWeb, :live_view

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {WikWeb.LiveUserAuth, :current_user}

  def on_mount(:ctx_additions, params, _session, socket) do
    dbg(params)
    {:cont, socket |> ctx_add(:page_slug, params["page_slug"])}
  end

  defp ctx_add(socket, key, value) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)
    ctx = Map.put(socket.assigns.ctx, key, value)
    socket |> assign(ctx: ctx)
  end
end
