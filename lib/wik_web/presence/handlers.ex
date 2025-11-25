defmodule WikWeb.Presence.Handlers do
  @moduledoc """
  Provides standardized handlers for Phoenix Presence events in LiveViews.

  Use this module in LiveViews that need to respond to user presence changes:

      use WikWeb.Presence.Handlers

  This will automatically add handlers for presence join, leave, and update events.
  """

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Handles a user joining the presence.

  Updates the socket's context with the latest presence information.
  """
  @spec handle_presence_join(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def handle_presence_join(socket) do
    presences = get_group_presences(socket)
    ctx = Map.put(socket.assigns.ctx, :presences, presences)
    assign(socket, :ctx, ctx)
  end

  @doc """
  Handles a user leaving the presence.

  Updates the socket's context with the latest presence information.
  """
  @spec handle_presence_leave(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def handle_presence_leave(socket) do
    presences = get_group_presences(socket)
    ctx = Map.put(socket.assigns.ctx, :presences, presences)
    assign(socket, :ctx, ctx)
  end

  @doc """
  Handles a presence update (e.g., user navigating to a different page).

  Updates the socket's context with the latest presence information.
  """
  @spec handle_presence_update(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def handle_presence_update(socket) do
    presences = get_group_presences(socket)
    ctx = Map.put(socket.assigns.ctx, :presences, presences)
    assign(socket, :ctx, ctx)
  end

  @spec get_group_presences(Phoenix.LiveView.Socket.t()) :: list(map())
  defp get_group_presences(socket) do
    case socket.assigns[:ctx][:current_group] do
      nil -> []
      group -> WikWeb.Presence.list_online_users_in_group(group.id)
    end
  end

  defmacro __using__(_opts) do
    quote do
      def handle_info({WikWeb.Presence, {:join, _presence}}, socket) do
        {:noreply, WikWeb.Presence.Handlers.handle_presence_join(socket)}
      end

      def handle_info({WikWeb.Presence, {:leave, _presence}}, socket) do
        {:noreply, WikWeb.Presence.Handlers.handle_presence_leave(socket)}
      end

      def handle_info({WikWeb.Presence, {:update, %{id: _id, meta: _meta}}}, socket) do
        {:noreply, WikWeb.Presence.Handlers.handle_presence_update(socket)}
      end
    end
  end
end
