defmodule WikWeb.UserLive.Index do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Users
        <:actions></:actions>
      </.header>

      <.table id="users" rows={@streams.users}>
        <:col :let={{_id, user}} label="Id">{user.id}</:col>
        <:col :let={{_id, user}} label="Email">{user.email}</:col>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Users")
     |> stream(:users, Ash.read!(Wik.Accounts.User, actor: socket.assigns[:current_user]))}
  end

  @impl true
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end
end
