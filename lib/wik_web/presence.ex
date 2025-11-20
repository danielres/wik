defmodule WikWeb.Presence do
  use Phoenix.Presence,
    otp_app: :wik,
    pubsub_server: Wik.PubSub

  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      # user can be populated here from the database here we populate
      # the name for demonstration purposes
      {key, %{metas: [meta | metas], id: meta.id, user: %{name: meta.id}}}
    end
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{id: user_id, user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {__MODULE__, {:join, user_data}}
      Phoenix.PubSub.local_broadcast(Wik.PubSub, "proxy:#{topic}", msg)
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{id: user_id, user: presence.user, metas: metas}
      msg = {__MODULE__, {:leave, user_data}}
      Phoenix.PubSub.local_broadcast(Wik.PubSub, "proxy:#{topic}", msg)
    end

    {:ok, state}
  end

  def track(user, path) do
    [username, _] = to_string(user.email) |> String.split("@", parts: 2)
    meta = %{id: user.id, username: username, path: path}
    track_user(user.id, meta)
    update(self(), "online_users", user.id, meta)
  end

  def track_in_liveview(socket, url) do
    if Phoenix.LiveView.connected?(socket) do
      path = URI.parse(url).path
      WikWeb.Presence.track(socket.assigns.current_user, path)
    end

    socket
  end

  def list_online_users(),
    do: list("online_users") |> Enum.map(fn {_id, presence} -> presence end)

  def track_user(name, params), do: track(self(), "online_users", name, params)

  def subscribe(), do: Phoenix.PubSub.subscribe(Wik.PubSub, "proxy:online_users")
end
