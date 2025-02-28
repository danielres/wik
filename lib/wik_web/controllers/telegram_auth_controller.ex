defmodule WikWeb.TelegramAuthController do
  use WikWeb, :controller
  alias Wik.User
  @login_ttl :timer.hours(24)
  require Logger

  defp bot_token, do: Application.get_env(:wik, :bot_token)

  def callback(conn, params) do
    # params is a map with Telegram authentication data:
    # e.g. %{"id" => "...", "first_name" => "...", "auth_date" => "...", "hash" => "..."}

    if valid_telegram_auth?(params, false) do
      user =
        User.get_or_create_from_telegram(params, bot_token())
        |> Map.delete("hash")
        |> Map.delete("auth_date")

      conn
      |> put_session(:user, user)
      |> put_flash(:info, "Welcome #{user.first_name} #{user.last_name} (#{user.username})!")
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Invalid Telegram login")
      |> redirect(to: "/")
    end
  end

  def miniapp(conn, _params) do
    with ["tma " <> init_data_raw] <- get_req_header(conn, "authorization"),
         params <- URI.decode_query(init_data_raw),
         true <- valid_telegram_auth?(params, true) do
      {:ok, params} = JSON.decode(params["user"])

      user = User.get_or_create_from_telegram(params, bot_token())

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

  defp valid_telegram_auth?(params, miniapp?) do
    # Get the received hash from params and remove it from the map.
    check_hash = Map.get(params, "hash") |> String.downcase()

    # Compute the secret key: SHA256(bot_token) in binary.
    secret_key =
      if miniapp? do
        :crypto.mac(:hmac, :sha256, "WebAppData", bot_token())
      else
        :crypto.hash(:sha256, bot_token())
      end

    # Create the data-check string.
    data_check_string =
      params
      |> Map.delete("hash")
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.sort()
      |> Enum.join("\n")

    # Compute the HMAC-SHA256 of the data-check string with the secret key.
    computed_hash =
      :crypto.mac(:hmac, :sha256, secret_key, data_check_string)
      |> Base.encode16(case: :lower)
      |> String.downcase()

    # Optionally, check that the authentication is not older than 24 hours.
    auth_date =
      case Map.get(params, "auth_date") do
        nil -> 0
        date when is_binary(date) -> String.to_integer(date)
        date when is_integer(date) -> date
      end

    current_time = System.os_time(:second)

    outdated? = current_time - auth_date > @login_ttl

    cond do
      computed_hash != check_hash ->
        false

      outdated? ->
        false

      true ->
        true
    end
  end
end
