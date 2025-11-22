defmodule WikWeb.Presence do
  @moduledoc """
  Manages user presence tracking across the application.

  This module tracks which users are currently online in each group,
  including the pages they are viewing. It extends Phoenix.Presence
  to provide group-scoped presence tracking.
  """

  use Phoenix.Presence,
    otp_app: :wik,
    pubsub_server: Wik.PubSub

  require Ash.Query

  @doc false
  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  @doc """
  Fetches user data for presence tracking.

  Enriches presence data with full user information from the database.
  """
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

  @doc """
  Tracks a user's presence in a specific group and path.

  ## Parameters
    - user: The user struct to track
    - path: The current path/URL the user is viewing
    - group_id: The ID of the group the user is in
  """
  @spec track_user_presence(Wik.Accounts.User.t(), String.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def track_user_presence(user, path, group_id) do
    # Only store non-user data in meta - user data will be added by fetch/2
    meta = %{path: path, group_id: group_id}
    topic = "group:#{group_id}:users"

    # Use Phoenix.Presence.track/4 to track the user in the group-specific topic
    track(self(), topic, user.id, meta)
    # Also update the presence meta for this process
    update(self(), topic, user.id, meta)
  end

  @doc """
  Tracks presence for a LiveView socket.

  Automatically extracts the path and group context from the socket
  and tracks the user's presence if they are in a group.
  """
  @spec track_in_liveview(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
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

  @doc """
  Lists all users currently online in a specific group.

  Returns a list of presence structs containing user information
  and metadata about their current location.
  """
  @spec list_online_users_in_group(String.t()) :: list(map())
  def list_online_users_in_group(group_id) do
    topic = "group:#{group_id}:users"
    list(topic) |> Enum.map(fn {_id, presence} -> presence end)
  end

  @doc """
  Subscribes the current process to presence updates for a specific group.
  """
  @spec subscribe_to_group(String.t()) :: :ok | {:error, term()}
  def subscribe_to_group(group_id) do
    topic = "group:#{group_id}:users"
    Phoenix.PubSub.subscribe(Wik.PubSub, "proxy:#{topic}")
  end

  # Legacy functions - deprecated but kept for backwards compatibility
  @deprecated "Use list_online_users_in_group/1 instead"
  def list_online_users(), do: []

  @deprecated "Use subscribe_to_group/1 instead"
  def subscribe(), do: :ok
end
