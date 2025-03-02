defmodule WikWeb.SuperAdmin.GroupLive.Index do
  use WikWeb, :live_view

  alias Wik.Groups
  alias Wik.Groups.Group

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:user, session["user"])
     |> stream(:groups, Groups.list_groups()), layout: {WikWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Group")
    |> assign(:group, Groups.get_group!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Group")
    |> assign(:group, %Group{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Groups")
    |> assign(:group, nil)
  end

  @impl true
  def handle_info({WikWeb.SuperAdmin.GroupLive.FormComponent, {:saved, group}}, socket) do
    {:noreply, stream_insert(socket, :groups, group)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    group = Groups.get_group!(id)
    {:ok, _} = Groups.delete_group(group)

    {:noreply, stream_delete(socket, :groups, group)}
  end
end
