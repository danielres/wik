defmodule WikWeb.Components.OnlineUsers do
  use Phoenix.Component

  def list(assigns) do
    ~H"""
    <ul id="online_users" class="space-y-4 text-xs">
      <li :for={%{id: id, user: user, metas: metas} <- @presences} id={id}>
        <div class="font-semibold">
          {user |> to_string}
          <sup>{length(metas)}</sup>
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
