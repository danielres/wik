defmodule WikWeb.GroupLive.Index do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Groups
        <:actions>
          <.button variant="primary" navigate={~p"/groups/new"}>
            <.icon name="hero-plus" /> New Group
          </.button>
        </:actions>
      </.header>

      <.table
        id="groups"
        rows={@streams.groups}
        row_click={fn {_id, group} -> JS.navigate(~p"/groups/#{group}") end}
      >
        <:col :let={{_id, group}} label="Id">{group.id}</:col>

        <:col :let={{_id, group}} label="Title">{group.title}</:col>

        <:col :let={{_id, group}} label="Text">{group.text}</:col>

        <:col :let={{_id, group}} label="Author">{group.author_id}</:col>

        <:action :let={{_id, group}}>
          <div class="sr-only">
            <.link navigate={~p"/groups/#{group}"}>Show</.link>
          </div>

          <.link navigate={~p"/groups/#{group}/edit"}>Edit</.link>
        </:action>

        <:action :let={{id, group}}>
          <.link
            phx-click={JS.push("delete", value: %{id: group.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Groups")
     |> assign_new(:current_user, fn -> nil end)
     |> stream(:groups, Ash.read!(Wik.Accounts.Group, actor: socket.assigns[:current_user]))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    group = Ash.get!(Wik.Accounts.Group, id, actor: socket.assigns.current_user)
    Ash.destroy!(group, actor: socket.assigns.current_user)

    {:noreply, stream_delete(socket, :groups, group)}
  end
end
