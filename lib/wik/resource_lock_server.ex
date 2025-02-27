defmodule Wik.ResourceLockServer do
  @moduledoc """
  A GenServer that tracks locks for resources.
  State is a map: %{resource_path => %{user_id => lock_count}}
  We enforce that a resource may only be locked by one user at a time.
  """

  use GenServer

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Attempt to lock a resource for a given user.
  Returns :ok if the resource is not locked,
  or {:error, reason} if it is locked.
  """
  def lock(resource_path, userinfo) do
    GenServer.call(__MODULE__, {:lock, resource_path, userinfo})
  end

  @doc """
  Unlock a resource for a given user.
  """
  def unlock(resource_path, user_id) do
    GenServer.call(__MODULE__, {:unlock, resource_path, user_id})
  end

  ## GenServer Callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_call({:lock, resource, userinfo}, _from, state) do
    user_id = userinfo.id

    case Map.get(state, resource) do
      nil ->
        # Resource is not locked; lock it for this user.
        new_state = Map.put(state, resource, %{user_id => 1})
        {:reply, :ok, new_state}

      lock_map ->
        if Map.has_key?(lock_map, user_id) do
          # The same user is already editing this resource.
          {:reply, {:error, "You are already editing this resource in another tab."}, state}
        else
          # Some other user holds the lock.
          {:reply, {:error, "This resource is currently being edited by #{userinfo.username}."},
           state}
        end
    end
  end

  def handle_call({:unlock, resource, user_id}, _from, state) do
    new_state =
      case Map.get(state, resource) do
        nil ->
          state

        lock_map ->
          new_lock_map = Map.delete(lock_map, user_id)

          if map_size(new_lock_map) == 0 do
            Map.delete(state, resource)
          else
            Map.put(state, resource, new_lock_map)
          end
      end

    {:reply, :ok, new_state}
  end
end
