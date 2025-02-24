defmodule WikWeb.SuperAdmin.RevisionLive.Show do
  use WikWeb, :live_view

  alias Wik.Revisions

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
     |> assign(:revision, Revisions.get_revision!(id))}
  end

  defp page_title(:show), do: "Show Revision"
  defp page_title(:edit), do: "Edit Revision"
end
