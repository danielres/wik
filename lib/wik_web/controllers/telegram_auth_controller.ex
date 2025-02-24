defmodule WikWeb.TelegramAuthController do
  use WikWeb, :controller

  # 86400 = 1 day in seconds
  @login_ttl :timer.hours(24)

  defp all_groups, do: Application.get_env(:wik, :all_groups, [])
  defp bot_token, do: Application.get_env(:wik, :bot_token)

  def callback(conn, params) do
    # params is a map with Telegram authentication data:
    # e.g. %{"id" => "...", "first_name" => "...", "auth_date" => "...", "hash" => "..."}

    if valid_telegram_auth?(params) do
      user = get_or_create_user_from_telegram(params)

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

  defp valid_telegram_auth?(params) do
    # Get the received hash from params and remove it from the map.
    check_hash = Map.get(params, "hash")
    data = Map.delete(params, "hash")

    # Create the data-check string.
    data_check_string =
      data
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.sort()
      |> Enum.join("\n")

    # Compute the secret key: SHA256(bot_token) in binary.
    secret_key = :crypto.hash(:sha256, bot_token())

    # Compute the HMAC-SHA256 of the data-check string with the secret key.
    computed_hash =
      :crypto.mac(:hmac, :sha256, secret_key, data_check_string)
      |> Base.encode16(case: :lower)

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

  defp get_or_create_user_from_telegram(params) do
    # For each group in all_groups, check if the user is a member.
    member_of =
      Enum.filter(all_groups(), fn group ->
        user_member_of?(group, params["id"])
      end)

    %{
      id: params["id"],
      first_name: params["first_name"],
      last_name: params["last_name"],
      auth_date: params["auth_date"],
      hash: params["hash"],
      username: params["username"],
      photo_url: params["photo_url"],
      member_of: member_of
    }
  end

  defp user_member_of?(group, user_id) do
    url =
      "https://api.telegram.org/bot#{bot_token()}/getChatMember?chat_id=#{group.id}&user_id=#{user_id}"

    req = Finch.build(:get, url)

    case Finch.request(req, WikWeb.Finch) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => %{"status" => status}}} ->
            status in ["member", "administrator", "creator"]

          _ ->
            false
        end

      _ ->
        false
    end
  end
end
