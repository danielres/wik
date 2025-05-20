defmodule Wik.ResourceLockServer do
  @moduledoc """
  A GenServer that tracks locks for resources.
  State is a map: %{resource_path => userinfo}
  Each resource may only be locked by one user at a time.
  """

  use GenServer

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Attempt to lock a resource for a given user.

  Returns:
    - :ok if the resource is not locked
    - {:error, :locked_by_same_user} if same user already holds the lock
    - {:error, :locked_by_other_user, userinfo} if another user holds the lock
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

  def init(state), do: {:ok, state}

  def handle_call({:lock, resource, userinfo = %{id: uid}}, _from, state) do

    case Map.get(state, resource) do
      nil ->
        new_state = state |> Map.put(resource, userinfo)
        {:reply, :ok, new_state}

      %{id: ^uid} ->
        {:reply, {:error, :locked_by_same_user}, state}

      locking_user_info ->
        {:reply, {:error, :locked_by_other_user, locking_user_info}, state}
    end
  end

  def handle_call({:unlock, resource, user_id}, _from, state) do
    case Map.get(state, resource) do
      %{id: ^user_id} -> {:reply, :ok, Map.delete(state, resource)}
      _ -> {:reply, :ok, state}
    end
  end
end
