defmodule Wik.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends magic link authentication emails to users.

  This sender is used by AshAuthentication to deliver magic link emails
  that allow users to sign in without a password.

  ## Configuration

  Configure the sender email address in your config files:

      config :wik, Wik.Accounts.User.Senders.SendMagicLinkEmail,
        from_email: "noreply@yourdomain.com",
        from_name: "Your App Name"
  """

  use AshAuthentication.Sender
  use WikWeb, :verified_routes

  import Swoosh.Email
  alias Wik.Mailer

  @default_from_name "Wik"
  @default_from_email "noreply@example.com"

  @impl true
  def send(user_or_email, token, _opts) do
    # Extract email whether we received a user struct or just an email string
    email =
      case user_or_email do
        %{email: email} -> email
        email when is_binary(email) -> email
      end

    from_config = get_from_config()

    new()
    |> from(from_config)
    |> to(to_string(email))
    |> subject("Your login link")
    |> html_body(build_email_body(token: token, email: email))
    |> Mailer.deliver!()
  end

  @spec get_from_config() :: {String.t(), String.t()}
  defp get_from_config do
    config = Application.get_env(:wik, __MODULE__, [])
    from_name = Keyword.get(config, :from_name, @default_from_name)
    from_email = Keyword.get(config, :from_email, @default_from_email)
    {from_name, from_email}
  end

  @spec build_email_body(keyword()) :: String.t()
  defp build_email_body(params) do
    magic_link_url = url(~p"/magic_link/#{params[:token]}")

    """
    <!DOCTYPE html>
    <html>
      <body>
        <p>Hello, #{params[:email]}!</p>
        <p>Click this link to sign in:</p>
        <p><a href="#{magic_link_url}">#{magic_link_url}</a></p>
        <p>This link will expire after use or a period of inactivity.</p>
      </body>
    </html>
    """
  end
end
