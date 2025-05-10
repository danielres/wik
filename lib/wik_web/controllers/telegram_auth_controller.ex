defmodule WikWeb.TelegramAuthController do
  use WikWeb, :controller
  alias Wik.Telegram
  require Logger

  def callback(conn, telegram_callback_response) do
    if Telegram.valid_telegram_auth?(telegram_callback_response, false) do
      session_user = make_session_user(telegram_callback_response)

      conn
      |> put_session(:user, session_user)
      |> configure_session(renew: true)
      |> redirect(to: get_session(conn, :redirect_after_login) || "/")
    else
      Logger.error("Invalid Telegram login")

      conn
      |> put_flash(:error, "Invalid Telegram login")
      |> redirect(to: "/")
    end
  end

  def miniapp(conn, _params) do
    with ["tma " <> init_data_raw] <- get_req_header(conn, "authorization"),
         params <- URI.decode_query(init_data_raw),
         true <- Telegram.valid_telegram_auth?(params, true) do
      {:ok, telegram_callback_response} = JSON.decode(params["user"])

      session_user = make_session_user(telegram_callback_response)

      conn
      |> put_session(:user, session_user)
      |> put_flash(
        :info,
        "Welcome #{session_user.first_name} #{session_user.last_name} (#{session_user.username})!"
      )
      |> json(%{success: true})
    else
      _ ->
        Logger.error("Invalid Telegram Mini App login")

        conn
        |> put_flash(:error, "Invalid Telegram login")
        |> json(%{success: false, error: "Invalid Telegram login"})
    end
  end

  def make_session_user(res) do
    telegram_user_data = %{
      telegram_id: "#{res["id"]}",
      first_name: res["first_name"],
      last_name: res["last_name"],
      auth_date: res["auth_date"],
      username: res["username"],
      photo_url: res["photo_url"]
    }

    {:ok, dbuser} = Wik.Users.create_or_update_user_by_telegram_id(telegram_user_data)

    session_user =
      telegram_user_data
      |> Map.put(:id, dbuser.id)
      |> Map.put(:member_of, Telegram.fetch_user_groups(res["id"]))

    session_user
  end
end
