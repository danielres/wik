defmodule WikWeb.SuperAdmin.RevisionLive.Index do
  use WikWeb, :live_view

  alias Wik.Revisions

  def make_route(), do: ~p"/admin/revisions"

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:user, session["user"])
      |> assign(:resource_paths, Revisions.list_distinct_resource_paths())

    {:ok, stream(socket, :revisions, []), layout: {WikWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # For index, check if a filter by resource_path was provided
  defp apply_action(socket, :index, params) do
    resource_path =
      Map.get(params, "resource_path") || socket.assigns.resource_paths |> List.first()

    revisions = Revisions.list_revisions_by_resource_path(resource_path)

    socket
    |> assign(:page_title, "Listing Revisions | Admin")
    |> assign(:resource_path, resource_path)
    |> assign(:revision, nil)
    |> assign(:filter, resource_path)
    |> stream(:revisions, revisions)
  end

  def handle_event("delete_all_by_resource_path", %{"resource_path" => resource_path}, socket) do
    Revisions.delete_all_by_resource_path(resource_path)
    {:noreply, socket |> push_navigate(to: make_route())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    revision = Revisions.get_revision!(id)
    {:ok, _} = Revisions.delete_revision(revision)

    {:noreply, stream_delete(socket, :revisions, revision)}
  end
end
