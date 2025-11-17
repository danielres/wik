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
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:ctx, %{current_user: socket.assigns.current_user})}
  end
end
