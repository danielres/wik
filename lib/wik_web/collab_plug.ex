defmodule WikWeb.CollabPlug do
  @moduledoc """
  WebSocket upgrade plug for Y.js collaboration.

  Handles WebSocket upgrade requests at /collab path and forwards
  Y.js updates between clients in real-time.
  """

  import Plug.Conn
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Wiki.Page
  require Logger

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/collab" <> room_path} = conn, _opts) do
    conn = conn |> fetch_session() |> AuthHelpers.retrieve_from_session(:wik)

    with true <- websocket_upgrade?(conn),
         {:ok, page_id} <- parse_room(room_path),
         %{id: _} = actor <- conn.assigns[:current_user],
         {:ok, page} <- Ash.get(Page, page_id, actor: actor) do
      can_edit? = Ash.can?({page, :update}, actor)
      handle_websocket_upgrade(conn, page_id, page, actor, can_edit?)
    else
      false ->
        conn |> send_resp(400, "WebSocket upgrade required") |> halt()

      {:error, :invalid_room} ->
        conn |> send_resp(400, "Invalid collaboration room") |> halt()

      nil ->
        conn |> send_resp(401, "Unauthorized") |> halt()

      {:error, %Ash.Error.Forbidden{} = _error} ->
        conn |> send_resp(403, "Forbidden") |> halt()

      {:error, :not_found} ->
        conn |> send_resp(404, "Not found") |> halt()

      {:error, reason} ->
        Logger.error("Collab websocket auth failure: #{inspect(reason)}")
        conn |> send_resp(403, "Forbidden") |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp handle_websocket_upgrade(conn, room_id, page, actor, can_edit?) do
    room = "page-#{room_id}"

    conn
    |> WebSockAdapter.upgrade(
      WikWeb.CollabWebSocket,
      [room: room, page: page, actor: actor, can_edit?: can_edit?],
      []
    )
    |> halt()
  end

  defp websocket_upgrade?(conn), do: get_req_header(conn, "upgrade") == ["websocket"]

  defp parse_room(room_path) do
    room =
      case room_path do
        "/" <> room_name -> room_name
        "" -> nil
        _ -> String.trim_leading(room_path, "/")
      end

    with true <- is_binary(room),
         ["page", id] <- String.split(room, "-", parts: 2),
         true <- id != "" do
      {:ok, id}
    else
      _ -> {:error, :invalid_room}
    end
  end
end
