defmodule WikWeb.PageLive.Show do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        {@page.title}
        <:subtitle>Page</:subtitle>

        <:actions>
          <.button navigate={~p"/#{@ctx.current_group.slug}/pages"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit Page
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Text">{@page.text}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"page_slug" => page_slug}, _session, socket) do
    # Wik.Accounts.Group
    # |> Ash.get!(%{slug: slug}, actor: socket.assigns.current_user, load: [:author])
    page =
      Wik.Wiki.Page
      |> Ash.get!(
        %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
        actor: socket.assigns.current_user
      )

    {:ok,
     socket
     |> assign(:page_title, "Show Page")
     |> assign(:page, page)}
  end
end
