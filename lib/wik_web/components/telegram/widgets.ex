defmodule WikWeb.Components.Telegram.Widgets do
  use Phoenix.Component

  # Optional attrs if you want to override defaults
  attr :class, :string, default: nil
  attr :request_access, :string, default: "write"
  attr :size, :string, default: "large", values: ~w(small medium large)

  def login(assigns) do
    bot_username =
      System.get_env("TELEGRAM_BOT_USERNAME") ||
        raise "TELEGRAM_BOT_USERNAME not set"

    assigns =
      assigns
      |> assign(:bot_username, bot_username)

    ~H"""
    <div
      id="telegram-login"
      phx-hook="TelegramLogin"
      phx-update="ignore"
      class={@class}
      data-bot-username={@bot_username}
      data-request-access={@request_access}
      data-size={@size}
    />
    """
  end
end
