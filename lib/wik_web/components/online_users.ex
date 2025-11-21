defmodule WikWeb.Components.OnlineUsers do
  use Phoenix.Component

  def list(assigns) do
    ~H"""
    <ul :if={@presences} id="online_users" class="space-y-4 text-xs">
      <li :for={%{id: id, user: user, metas: metas} <- @presences} id={id}>
        <div class="font-semibold">
          {user |> to_string}
          <sup class="opacity-50">{length(metas)}</sup>
        </div>
        <ul class="pl-2">
          <li :for={meta <- metas}>
            <.link navigate={meta.path} class="opacity-75 hover:opacity-100 transition">
              {meta.path |> pretty_path()}
            </.link>
          </li>
        </ul>
      </li>
    </ul>
    """
  end

  defp pretty_path(path) when is_binary(path) do
    case String.split(path, "/") do
      ["", first_segment | rest] when first_segment != "" ->
        res = Enum.join(rest, "/")
        (res == "" && "home") || res

      _ ->
        path
    end
  end
end
