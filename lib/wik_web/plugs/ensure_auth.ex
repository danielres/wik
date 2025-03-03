defmodule WikWeb.Plugs.EnsureAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = get_session(conn, :user)

    if user do
      conn |> assign(:user, user)
    else
      conn
      |> put_session(:redirect_after_login, conn.request_path)
      |> put_status(:unauthorized)
      |> put_view(WikWeb.PageHTML)
      |> render("ensure_auth.html")
      |> halt()
    end
  end
end
