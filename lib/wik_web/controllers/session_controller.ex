defmodule WikWeb.SessionController do
  use WikWeb, :controller

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/pages/home")
  end
end
