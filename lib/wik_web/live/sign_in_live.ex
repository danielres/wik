defmodule WikWeb.SignInLive do
  @moduledoc """
  """

  use WikWeb, :live_view
  alias WikWeb.Components.RealtimeToast
  alias WikWeb.Components

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Components.Telegram.Widgets.login />
      <div :if={Mix.env() == :dev} class="text-center mt-4">
        <.link class="btn btn-primary" navigate="/dev/login">dev login</.link>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    dbg("🔴")
    dbg(socket.assigns)
    {:ok, socket}
  end
end
