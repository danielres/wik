defmodule WikWeb.Components.OnlineUsers do
  use Phoenix.Component

  def list(assigns) do
    ~H"""
    <ul :if={@presences} id="online_users" class="space-y-8">
      "
      <li :for={%{id: id, metas: metas} <- @presences} id={id}>
        <div class="font-semibold">
          {List.first(metas).username} <sup>{length(metas)}</sup>
        </div>
        <ul class="pl-4">
          <li :for={meta <- metas}>
            <.link navigate={meta.path}>
              {meta.path}
            </.link>
          </li>
        </ul>
      </li>
    </ul>
    """
  end
end
