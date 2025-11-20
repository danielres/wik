defmodule WikWeb.Presence.Handlers do
  import Phoenix.Component, only: [assign: 3]

  def handle_presence_join(socket) do
    ctx = Map.put(socket.assigns.ctx, :presences, WikWeb.Presence.list_online_users())
    assign(socket, :ctx, ctx)
  end

  def handle_presence_leave(socket) do
    ctx = Map.put(socket.assigns.ctx, :presences, WikWeb.Presence.list_online_users())
    assign(socket, :ctx, ctx)
  end

  def handle_presence_update(socket) do
    ctx = Map.put(socket.assigns.ctx, :presences, WikWeb.Presence.list_online_users())
    assign(socket, :ctx, ctx)
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
