defmodule WikWeb.PageLive.Show do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        {@page.title}

        <:subtitle>
          <.link
            patch={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/v/#{@page.versions_count}"}
            class="btn btn-sm btn-neutral text-base-content/50"
          >
            v. {@page.versions_count}
          </.link>
        </:subtitle>

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

      <main>{@page.text}</main>
    </Layouts.app>
    """
  end

  def get_page_version(page_id, version_number, actor) do
    require Ash.Query

    Wik.Events.Event
    |> Ash.Query.filter(record_id == ^page_id and resource == "Wik.Wiki.Page")
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.Query.offset(version_number - 1)
    |> Ash.Query.limit(1)
    |> Ash.read_one(actor: actor)
  end

  @impl true
  def mount(%{"page_slug" => page_slug}, _session, socket) do
    case Wik.Wiki.Page
         |> Ash.get(
           %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
           actor: socket.assigns.current_user,
           load: [:versions_count]
         ) do
      {:ok, page} ->
        {:ok,
         socket
         |> assign(:page_title, page.title)
         |> assign(:page, page)}

      {:error, _error} ->
        page =
          Wik.Wiki.Page
          |> Ash.Changeset.for_create(
            :create,
            %{title: page_slug},
            actor: socket.assigns.current_user,
            context: %{shared: %{current_group_id: socket.assigns.ctx.current_group.id}}
          )
          |> Ash.create!()

        {:ok,
         socket
         |> push_navigate(to: ~p"/#{socket.assigns.ctx.current_group.slug}/pages/#{page.slug}")}
    end
  end
end
