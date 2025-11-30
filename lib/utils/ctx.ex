defmodule Utils.Ctx do
  import Phoenix.Component

  def add(socket, key, value) do
    socket = socket |> assign_new(:ctx, fn -> %{} end)
    ctx = Map.put(socket.assigns.ctx, key, value)
    socket |> assign(ctx: ctx)
  end
end
