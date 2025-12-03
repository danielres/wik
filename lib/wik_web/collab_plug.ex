defmodule WikWeb.CollabPlug do
  @moduledoc """
  WebSocket upgrade plug for Y.js collaboration.

  Handles WebSocket upgrade requests at /collab path and forwards
  Y.js updates between clients in real-time.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/collab" <> room_path} = conn, _opts) do
    if websocket_upgrade?(conn) do
      handle_websocket_upgrade(conn, room_path)
    else
      conn
      |> send_resp(400, "WebSocket upgrade required")
      |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp handle_websocket_upgrade(conn, room_path) do
    # Extract room name from URL path (y-websocket appends room to URL)
    room =
      case room_path do
        "/" <> room_name -> room_name
        "" -> "default"
        _ -> String.trim_leading(room_path, "/")
      end

    # TODO: Add authentication/authorization for collab socket

    conn
    |> WebSockAdapter.upgrade(WikWeb.CollabWebSocket, [room: room], [])
    |> halt()
  end

  defp websocket_upgrade?(conn), do: get_req_header(conn, "upgrade") == ["websocket"]
end
