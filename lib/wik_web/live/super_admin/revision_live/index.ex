defmodule WikWeb.SuperAdmin.RevisionLive.Index do
  use WikWeb, :live_view

  alias Wik.Revisions
  alias Wik.Revisions.Revision

  @impl true
  def mount(_params, session, socket) do
    user = session["user"]
    socket = socket |> assign(:user, user)

    {:ok, stream(socket, :revisions, Revisions.list_revisions()),
     layout: {WikWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Revision")
    |> assign(:revision, Revisions.get_revision!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Revision")
    |> assign(:revision, %Revision{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Revisions")
    |> assign(:revision, nil)
  end

  @impl true
  def handle_info({WikWeb.SuperAdmin.RevisionLive.FormComponent, {:saved, revision}}, socket) do
    {:noreply, stream_insert(socket, :revisions, revision)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    revision = Revisions.get_revision!(id)
    {:ok, _} = Revisions.delete_revision(revision)

    {:noreply, stream_delete(socket, :revisions, revision)}
  end
end
