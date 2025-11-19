defmodule WikWeb.HomeLive do
  use WikWeb, :live_view

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Home
        <:subtitle></:subtitle>

        <:actions></:actions>
      </.header>
      <ul>
        <li>
          <.link class="btn" navigate={~p"/groups"}>Groups</.link>
        </li>
      </ul>

      <:aside>
        {live_render(@socket, WikWeb.OnlineUsersLive, id: "online-users")}
      </:aside>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      WikWeb.Presence.track_in_liveview(current_user, "/")
    end

    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:ctx, %{current_user: current_user})}
  end
end
