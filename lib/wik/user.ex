defmodule Wik.User do
  def get_or_create_from_telegram(params, bot_token, opts \\ []) do
    # Inject a membership-checker function if provided; otherwise use the default.
    membership_checker = Keyword.get(opts, :membership_checker, &user_member_of?/3)

    # For each group, check if the user is a member.
    all_groups = Wik.Groups.list_groups()

    filtered =
      all_groups
      |> Enum.filter(fn group ->
        membership_checker.(group, params["id"], bot_token)
      end)

    serialized =
      filtered
      |> Enum.map(fn group ->
        %{
          id: group.id,
          name: group.name,
          slug: group.slug
        }
      end)

    %{
      id: "#{params["id"]}",
      first_name: params["first_name"],
      last_name: params["last_name"],
      auth_date: params["auth_date"],
      username: params["username"],
      photo_url: params["photo_url"],
      member_of: serialized
    }
  end

  defp user_member_of?(group, user_id, bot_token) do
    url =
      "https://api.telegram.org/bot#{bot_token}/getChatMember?chat_id=#{group.id}&user_id=#{user_id}"

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
