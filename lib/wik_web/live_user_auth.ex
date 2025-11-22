defmodule WikWeb.LiveUserAuth do
  @moduledoc """
  Provides authentication and authorization hooks for LiveViews.

  This module implements Phoenix LiveView's `on_mount` callbacks to handle
  various authentication scenarios:

  - `:current_user` - Assigns current user from session
  - `:live_user_optional` - User may or may not be present
  - `:live_user_required` - Redirects to sign-in if no user
  - `:live_no_user` - Redirects to home if user is present
  - `:group_membership_required` - Verifies user belongs to group
  - `:subscribe_presence` - Subscribes to presence updates for the group

  ## Usage

  Add to your LiveView or in router's `live_session`:

      on_mount {WikWeb.LiveUserAuth, :live_user_required}
  """
  import Phoenix.Component
  import Phoenix.LiveView, only: [connected?: 1]
  use WikWeb, :verified_routes
  use WikWeb, :live_view

  @doc """
  Assigns current user resources from the session.

  Used for nested LiveViews that need access to the current user.
  """
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  @doc """
  Ensures the current_user assign exists, even if nil.

  Use for pages where authentication is optional.
  """
  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  @doc """
  Requires an authenticated user to access the LiveView.

  Redirects to sign-in page if no user is present.
  """
  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket |> ctx_add(:current_user, socket.assigns[:current_user])}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  @doc """
  Verifies the user has access to the group specified in params.

  Expects a "slug" parameter in the route params. Redirects to home
  if the group is not found or the user doesn't have access.
  """
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

  @doc """
  Ensures no user is authenticated.

  Used for pages like sign-in/register where authenticated users
  should be redirected to the home page.
  """
  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  @doc """
  Subscribes to presence updates for the current group.

  Should be used after `:group_membership_required` to enable
  real-time user presence tracking.
  """
  def on_mount(:subscribe_presence, _params, _session, socket) do
    if connected?(socket) do
      # Subscribe to group-specific presence if we have a current group
      case socket.assigns[:ctx][:current_group] do
        nil ->
          {:cont, socket |> ctx_add(:presences, [])}

        group ->
          WikWeb.Presence.subscribe_to_group(group.id)
          presences = WikWeb.Presence.list_online_users_in_group(group.id)
          {:cont, socket |> ctx_add(:presences, presences)}
      end
    else
      # Initialize presences even when not connected
      {:cont, socket |> ctx_add(:presences, [])}
    end
  end

  @doc """
  Adds a key-value pair to the socket's context map.

  The context map is used to pass group-scoped data and settings
  to components and templates.
  """
  @spec ctx_add(Phoenix.LiveView.Socket.t(), atom(), any()) :: Phoenix.LiveView.Socket.t()
  defp ctx_add(socket, key, value) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)
    ctx = Map.put(socket.assigns.ctx, key, value)
    socket |> assign(ctx: ctx)
  end
end
