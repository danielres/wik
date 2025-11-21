defmodule WikWeb.PageLive.Index do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        Pages
        <:actions>
          <.button variant="primary" navigate={~p"/#{@ctx.current_group.slug}/new-page"}>
            <.icon name="hero-plus" /> New Page
          </.button>
        </:actions>
      </.header>

      <.table
        id="pages"
        rows={@streams.pages}
        row_click={
          fn {_id, page} -> JS.navigate(~p"/#{@ctx.current_group.slug}/pages/#{page.slug}") end
        }
      >
        <:col :let={{_id, page}} label="Title">{page.title}</:col>
        <:col :let={{_id, page}} label="Slug">{page.slug}</:col>
        <:col :let={{_id, page}} label="Text">{page.text}</:col>

        <:action :let={{id, page}}>
          <.link
            phx-click={JS.push("delete", value: %{id: page.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "Listing Pages")
     |> assign_new(:current_user, fn -> nil end)
     |> stream(:pages, Ash.read!(Wik.Wiki.Page, actor: socket.assigns[:current_user]))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    page = Ash.get!(Wik.Wiki.Page, id, actor: socket.assigns.current_user)
    Ash.destroy!(page, actor: socket.assigns.current_user)

    {:noreply, stream_delete(socket, :pages, page)}
  end
end
