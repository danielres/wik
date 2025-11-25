defmodule WikWeb.PageLive.History do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        {@version.data["title"]}

        <:subtitle>
          <div class="space-y-1">
            <div class="join mt-4">
              <.button
                disabled={@v == 1}
                patch={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/v/#{@v - 1}"}
                class="btn btn-sm btn-square btn-primary rounded-l-lg"
              >
                <i class="hero-arrow-left size-4"></i>
              </.button>
              <span class="btn btn-sm btn-outline btn-neutral pointer-events-none text-white">
                {@v}
                <span class="opacity-75">/</span>
                {@page.versions_count}
              </span>
              <.button
                disabled={@v == @page.versions_count}
                patch={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/v/#{@v + 1}"}
                class="btn btn-sm btn-square btn-primary rounded-r-lg"
              >
                <i class="hero-arrow-right size-4"></i>
              </.button>
            </div>

            <div>
              <span class="opacity-50">by</span>
              <.link class="opacity-80 hover:opacity-100 transition">
                {@author |> to_string()}
              </.link>
              <span class="opacity-50">on</span>
              <span class="">{@version.occurred_at}</span>
            </div>
          </div>
        </:subtitle>

        <:actions>
          <.button navigate={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}"}>
            <.icon name="hero-arrow-left" />
          </.button>
        </:actions>
      </.header>

      <%= if @version.data["text"] do %>
        {@version.data["text"]}
      <% else %>
        <div class="opacity-50">(Empty)</div>
      <% end %>
    </Layouts.app>
    """
  end

  def get_page_version(page_id, version_number, actor) do
    require Ash.Query

    Wik.Versions.Version
    |> Ash.Query.filter(record_id == ^page_id and resource == ^Wik.Wiki.Page)
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.Query.offset(version_number - 1)
    |> Ash.Query.limit(1)
    |> Ash.read_one(actor: actor)
  end

  @impl true
  def mount(%{"page_slug" => page_slug}, _session, socket) do
    page =
      Wik.Wiki.Page
      |> Ash.get!(
        %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
        actor: socket.assigns.current_user,
        load: [:versions_count]
      )

    socket = socket |> assign(:page, page)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"version" => v}, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)

    v = v |> String.to_integer()

    {:ok, version} = get_page_version(socket.assigns.page.id, v, socket.assigns.current_user)
    author_id = version.user_id
    author = Wik.Accounts.User |> Ash.get!(author_id, actor: socket.assigns.current_user)

    socket =
      socket
      |> assign(:version, version)
      |> assign(:v, v)
      |> assign(:author, author)

    {:noreply, socket}
  end
end
