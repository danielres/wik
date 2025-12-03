defmodule WikWeb.CollabWebSocket do
  @moduledoc """
  WebSocket handler implementing y-websocket protocol for Y.js collaboration.

  Forwards binary Y.js updates between clients in the same room.
  Compatible with standard y-websocket client library.
  """

  @behaviour WebSock

  require Logger
  alias WikWeb.CollabRoom
  alias Yex.Sync.SharedDoc

  @impl true
  def init(room: room, page: page, actor: actor, can_edit?: can_edit?) do
    with {:ok, doc_server} <- CollabRoom.fetch_or_start(room),
         :ok <- SharedDoc.observe(doc_server) do
      Logger.debug("Y.js client connected to room: #{room}")

      {:ok,
       %{
         room: room,
         doc_server: doc_server,
         page: page,
         actor: actor,
         can_edit?: can_edit?
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to start collab room #{room}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_in({:binary, data}, state) do
    if state.can_edit? do
      SharedDoc.send_yjs_message(state.doc_server, data)
    end

    {:ok, state}
  end

  # Bandit will deliver frames as `{data, [opcode: :binary]}` too
  def handle_in({data, [opcode: :binary]}, state) when is_binary(data) do
    if state.can_edit? do
      SharedDoc.send_yjs_message(state.doc_server, data)
    end

    {:ok, state}
  end

  @impl true
  def handle_in({:text, _text}, state) do
    # Y.js uses binary protocol, ignore text messages
    {:ok, state}
  end

  def handle_in({:ping, data}, state), do: {:push, {:pong, data}, state}
  def handle_in({:pong, _data}, state), do: {:ok, state}
  def handle_in({:close, _code, _reason}, state), do: {:stop, :normal, state}

  @impl true
  def handle_info({:yjs, message, _server}, state) do
    {:push, {:binary, message}, state}
  end

  def handle_info(_info, state), do: {:ok, state}

  @impl true
  def terminate(_reason, %{room: room, doc_server: doc_server}) do
    SharedDoc.unobserve(doc_server)
    Logger.debug("Y.js client disconnected from room: #{room}")
    :ok
  end
end
