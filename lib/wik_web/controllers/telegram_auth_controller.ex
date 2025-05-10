defmodule WikWeb.TelegramAuthController do
  use WikWeb, :controller
  alias Wik.User
  alias Wik.Telegram
  require Logger

  def callback(conn, params) do
    # params is a map with Telegram authentication data:
    # e.g. %{"id" => "...", "first_name" => "...", "auth_date" => "...", "hash" => "..."}

    if Telegram.valid_telegram_auth?(params, false) do
      user =
        User.get_or_create_from_telegram(params, Telegram.bot_token())
        |> Map.delete("hash")
        |> Map.delete("auth_date")

      dbuser = Wik.Users.persist_session_user(user)
      session_user = user
      dbg(dbuser)
      dbg(session_user)

      conn
      |> put_session(:user, user)
      |> configure_session(renew: true)
      |> redirect(to: get_session(conn, :redirect_after_login) || "/")
    else
      conn
      |> put_flash(:error, "Invalid Telegram login")
      |> redirect(to: "/")
    end
  end

  def miniapp(conn, _params) do
    with ["tma " <> init_data_raw] <- get_req_header(conn, "authorization"),
         params <- URI.decode_query(init_data_raw),
         true <- Telegram.valid_telegram_auth?(params, true) do
      {:ok, params} = JSON.decode(params["user"])

      user = User.get_or_create_from_telegram(params, Telegram.bot_token())
      Wik.Users.persist_session_user(user)

      conn
      |> put_session(:user, user)
      |> put_flash(:info, "Welcome #{user.first_name} #{user.last_name} (#{user.username})!")
      |> json(%{success: true})
    else
      _ ->
        Logger.error("Invalid Telegram Mini App login")

        conn
        |> put_flash(:error, "Invalid Telegram login")
        |> json(%{success: false, error: "Invalid Telegram login"})
    end
  end
end
