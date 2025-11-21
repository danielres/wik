defmodule WikWeb.Presence do
  use Phoenix.Presence,
    otp_app: :wik,
    pubsub_server: Wik.PubSub

  require Ash.Query

  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  def fetch(_topic, presences) do
    user_id_list = Map.keys(presences)

    users =
      Wik.Accounts.User
      |> Ash.Query.filter(id in ^user_id_list)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, &1})

    # Build presence data with real user information
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      {key, %{metas: [meta | metas], id: key, user: Map.get(users, key)}}
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

  def track_user_presence(user, path, group_id) do
    # Only store non-user data in meta - user data will be added by fetch/2
    meta = %{path: path, group_id: group_id}
    topic = "group:#{group_id}:users"

    # Use Phoenix.Presence.track/4 to track the user in the group-specific topic
    track(self(), topic, user.id, meta)
    # Also update the presence meta for this process
    update(self(), topic, user.id, meta)
  end

  def track_in_liveview(socket, url) do
    if Phoenix.LiveView.connected?(socket) do
      path = URI.parse(url).path

      # Check if we have a current group context
      case socket.assigns[:ctx][:current_group] do
        nil ->
          # No group context - could be home page or user index
          :ok

        group ->
          track_user_presence(socket.assigns.current_user, path, group.id)
      end
    end

    socket
  end

  # Group-specific presence functions
  def list_online_users_in_group(group_id) do
    topic = "group:#{group_id}:users"
    list(topic) |> Enum.map(fn {_id, presence} -> presence end)
  end

  def subscribe_to_group(group_id) do
    topic = "group:#{group_id}:users"
    Phoenix.PubSub.subscribe(Wik.PubSub, "proxy:#{topic}")
  end

  # Legacy function - deprecated but kept for backwards compatibility
  def list_online_users(), do: []
  def subscribe(), do: :ok
end
