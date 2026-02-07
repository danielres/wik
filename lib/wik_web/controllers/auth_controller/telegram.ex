defmodule WikWeb.AuthController.Telegram do
  use WikWeb, :controller
  require Ash.Query
  require Logger
  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Assent.Strategy.Telegram

  defp config do
    [
      bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
      # `, may be one of `:login_widget` or `:web_mini_app`
      authorization_channel: :login_widget,
      origin: ""
      # return_to: "/"
      # client_id: "REPLACE_WITH_CLIENT_ID",
      # client_secret: "REPLACE_WITH_CLIENT_SECRET",
      # redirect_uri: "http://localhost:4000/auth/telegram /callback"
    ]
  end

  def request(conn) do
    config()
    |> Telegram.authorize_url()
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        conn = put_session(conn, :session_params, session_params)

        # Redirect end-user to Telegram to authorize access to their account
        conn
        |> put_resp_header("location", url)
        |> send_resp(302, "")

      {:error, error} ->
        Logger.error("""
          Error in AuthController.Telegram.authorize_url()
          #{inspect(error)}
        """)

        nil
    end
  end

  def callback(conn, params) do
    return_to = params["return_to"]
    params = params |> Map.delete("return_to")
    session_params = get_session(conn, :session_params)

    config()
    # Session params should be added to the config so the strategy can use them
    |> Keyword.put(:session_params, session_params)
    |> Telegram.callback(params)
    |> case do
      {:ok, %{user: user_from_telegram}} ->
        attrs = %{
          tg_id: user_from_telegram["sub"] |> to_string(),
          tg_first_name: user_from_telegram["given_name"],
          tg_last_name: user_from_telegram["family_name"],
          tg_username: user_from_telegram["preferred_username"],
          tg_photo_url: user_from_telegram["picture"]
        }

        db_user =
          Wik.Accounts.User
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create!(upsert?: true, upsert_identity: :unique_tg_id)

        {:ok, token, _claims} = Jwt.token_for_user(db_user)
        db_user = Ash.Resource.set_metadata(db_user, %{token: token})

        # current_user = %{
        #   id: db_user.id,
        #   first_name: db_user.telegram_first_name,
        #   last_name: db_user.telegram_last_name,
        #   username: db_user.telegram_username,
        #   photo_url: db_user.telegram_photo_url,
        #   role: db_user.role
        # }

        conn
        |> AuthHelpers.store_in_session(db_user)
        |> redirect(to: return_to)

      {:error, error} ->
        error_id = :rand.uniform(10_000)

        Logger.error("""
          Error #{error_id} in AuthController.Telegram.callback()
          #{inspect(error)}
        """)

        conn
        |> put_flash(:error, "Authentication failed. Error id: #{error_id}")
        |> redirect(to: return_to)
    end
  end
end
