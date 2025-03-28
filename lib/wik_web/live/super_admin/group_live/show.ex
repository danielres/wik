defmodule WikWeb.SuperAdmin.GroupLive.Show do
  use WikWeb, :live_view

  alias Wik.Groups

  @impl true
  def mount(_params, session, socket) do
    user = session["user"]
    socket = socket |> assign(:user, user)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:group, Groups.get_group!(id))}
  end

  defp page_title(:edit), do: "Edit Group"
end
