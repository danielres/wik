defmodule Wik.Telegram do
  @login_ttl :timer.hours(24)

  def bot_token, do: Application.get_env(:wik, :bot_token)

  def valid_telegram_auth?(params, miniapp?) do
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
