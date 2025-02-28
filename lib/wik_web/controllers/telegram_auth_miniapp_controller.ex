defmodule WikWeb.TelegramMiniappAuthController do
  use WikWeb, :controller
  require Logger
  alias Wik.User

  @login_ttl :timer.hours(24)

  defp bot_token, do: Application.get_env(:wik, :bot_token)

  def miniapp(conn, _params) do
    with ["tma " <> init_data_raw] <- get_req_header(conn, "authorization"),
         params <- URI.decode_query(init_data_raw),
         true <- valid_telegram_miniapp_auth?(params) do
      params = params["user"]
      {:ok, params} = JSON.decode(params)

      # params = %{
      #   "first_name" => "Daniel",
      #   "id" => 458_778_600,
      #   "language_code" => "en",
      #   "last_name" => "R",
      #   "photo_url" =>
      #     "https://t.me/i/userpic/320/zZLjKqmklM6r0VHEuZ2xaNR8gTpqmtXljg3mYh6Q1dQ.svg",
      #   "username" => "danirez"
      # }

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

  defp valid_telegram_miniapp_auth?(params) do
    check_hash = Map.get(params, "hash") |> String.downcase()

    # Step 1: Compute the secret key (HMAC-SHA256 of bot token with "WebAppData")
    secret_key = :crypto.mac(:hmac, :sha256, "WebAppData", bot_token())

    # Step 2: Create the data-check string (all params except hash, sorted alphabetically)
    data_check_string =
      params
      |> Map.delete("hash")
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.sort()
      |> Enum.join("\n")

    # Step 3: Compute HMAC-SHA256 using the secret key from Step 1
    computed_hash =
      :crypto.mac(:hmac, :sha256, secret_key, data_check_string)
      |> Base.encode16(case: :lower)
      |> String.downcase()

    if computed_hash == check_hash do
      true
    else
      IO.puts("Invalid Telegram Mini App login: Hash mismatch.")
      false
    end
  end
end
