defmodule WikWeb.Components.OnlineUsers do
  @moduledoc """
  Component for displaying a list of currently online users.

  Shows users currently present in a group along with the pages they are viewing.
  """

  use Phoenix.Component

  @doc """
  Renders a list of online users with their current locations.

  ## Assigns
    - presences: List of presence data for online users
  """
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

  @spec pretty_path(String.t()) :: String.t()
  defp pretty_path(path) when is_binary(path) do
    case String.split(path, "/", trim: true) do
      [] ->
        "home"

      [_first_segment | rest] ->
        joined = Enum.join(rest, "/")
        if joined == "", do: "home", else: joined
    end
  end
end
