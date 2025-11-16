defmodule WikWeb.GroupLive.Show do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Group {@group.id}
        <:subtitle>This is a group record from your database.</:subtitle>

        <:actions>
          <.button navigate={~p"/groups"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/groups/#{@group}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit Group
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@group.id}</:item>

        <:item title="Title">{@group.title}</:item>

        <:item title="Text">{@group.text}</:item>

        <:item title="Author">{@group.author_id}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Group")
     |> assign(:group, Ash.get!(Wik.Accounts.Group, id, actor: socket.assigns.current_user))}
  end
end
