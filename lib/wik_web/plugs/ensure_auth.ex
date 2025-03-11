defmodule WikWeb.Plugs.EnsureAuth do
  @moduledoc """
  Plug to ensure that a user is authenticated. If a user is authenticated,
  the user information is assigned to the connection. Otherwise, an
  unauthorized status is set, and a redirection path is stored.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = get_session(conn, :user)

    if user do
      conn |> assign(:user, user)
    else
      handle_unauthenticated(conn)
    end
  end

  defp handle_unauthenticated(conn) do
    conn
    |> put_session(:redirect_after_login, conn.request_path)
    |> put_status(:unauthorized)
    |> put_view(WikWeb.PageHTML)
    |> render("ensure_auth.html")
    |> halt()
  end
end
