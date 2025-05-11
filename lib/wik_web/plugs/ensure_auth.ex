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
      normalized_user = normalize_user(user)
      conn |> assign(:user, normalized_user)
    else
      handle_unauthenticated(conn)
    end
  end

  # TODO: remove this after a few days, this is only needed temporarily following user refactor in #255b58ed
  #
  defp normalize_user(user) do
    if Map.has_key?(user, :telegram_id) do
      user
    else
      telegram_id = user.id
      db_user = Wik.Users.find_user_by_telegram_id(telegram_id)

      user
      |> Map.put(:telegram_id, telegram_id)
      |> Map.put(:id, db_user.id)
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
