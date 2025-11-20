defmodule WikWeb.Presence.Handlers do
  import Phoenix.Component, only: [assign: 3]

  def handle_presence_join(socket) do
    presences = get_group_presences(socket)
    ctx = Map.put(socket.assigns.ctx, :presences, presences)
    assign(socket, :ctx, ctx)
  end

  def handle_presence_leave(socket) do
    presences = get_group_presences(socket)
    ctx = Map.put(socket.assigns.ctx, :presences, presences)
    assign(socket, :ctx, ctx)
  end

  def handle_presence_update(socket) do
    presences = get_group_presences(socket)
    ctx = Map.put(socket.assigns.ctx, :presences, presences)
    assign(socket, :ctx, ctx)
  end

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
