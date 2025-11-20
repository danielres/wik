defmodule WikWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  import Phoenix.Component
  import Phoenix.LiveView, only: [connected?: 1]
  use WikWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {WikWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)

    if socket.assigns[:current_user] do
      ctx = Map.put(socket.assigns.ctx, :current_user, socket.assigns[:current_user])
      {:cont, socket |> assign(:ctx, ctx)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:subscribe_presence, _params, _session, socket) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)

    if connected?(socket) do
      WikWeb.Presence.subscribe()
      ctx = Map.put(socket.assigns.ctx, :presences, WikWeb.Presence.list_online_users())
      {:cont, socket |> assign(:ctx, ctx)}
    else
      {:cont, socket}
    end
  end
end
