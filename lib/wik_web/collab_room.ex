defmodule WikWeb.CollabRoom do
  @moduledoc """
  Manages per-room Yjs SharedDoc processes for collaboration.

  Uses a Registry + DynamicSupervisor to ensure one SharedDoc per room.
  """

  alias Yex.Sync.SharedDoc

  @registry Wik.CollabRegistry
  @supervisor Wik.CollabDocSupervisor

  @doc """
  Fetch the SharedDoc process for a room, starting it if needed.
  """
  @spec fetch_or_start(String.t()) :: {:ok, pid()} | {:error, term()}
  def fetch_or_start(room) when is_binary(room) do
    case Registry.lookup(@registry, room) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        start_room(room)
    end
  end

  defp start_room(room) do
    spec = %{
      id: {:collab_doc, room},
      start:
        {SharedDoc, :start_link,
         [[doc_name: room, auto_exit: false], [name: {:via, Registry, {@registry, room}}]]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(@supervisor, spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, {:shutdown, {:failed_to_start_child, _child, {:already_started, pid}}}} ->
        {:ok, pid}

      error ->
        error
    end
  end
end
