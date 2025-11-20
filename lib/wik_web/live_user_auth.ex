defmodule WikWeb.LiveUserAuth do
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
    if socket.assigns[:current_user] do
      {:cont, socket |> ctx_add(:current_user, socket.assigns[:current_user])}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:group_membership_required, %{"slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    # returns NotFoundError if policies don't allow access
    case Wik.Accounts.Group
         |> Ash.get(%{slug: slug}, actor: user, load: [:users]) do
      {:error, _} ->
        {:halt,
         socket
         |> put_flash(:info, ~s( Group "#{slug}" not found ))
         |> Phoenix.LiveView.redirect(to: ~p"/")}

      {:ok, group} ->
        {:cont, socket |> ctx_add(:current_group, group)}
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
    if connected?(socket) do
      WikWeb.Presence.subscribe()
      {:cont, socket |> ctx_add(:presences, WikWeb.Presence.list_online_users())}
    else
      {:cont, socket}
    end
  end

  defp ctx_add(socket, key, value) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)
    ctx = Map.put(socket.assigns.ctx, key, value)
    socket |> assign(ctx: ctx)
  end
end
