defmodule WikWeb.GroupLive.PageLive.History do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <div class="flex grid grid-cols-3 mb-12">
        <div>
          <.button
            navigate={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}"}
            class="btn btn-sm btn-circle btn-ghost opacity-50 hover:opacity-100 transition "
          >
            <.icon name="hero-arrow-left-micro size-5" />
          </.button>
        </div>

        <div class="space-y-0">
          <div class="join w-full flex justify-center">
            <.button
              disabled={@v == 1}
              patch={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}/v/#{@v - 1}"}
              class="btn btn-sm btn-circle btn-ghost"
            >
              <i class="hero-chevron-left size-4"></i>
            </.button>

            <span class="btn btn-sm btn-ghost pointer-events-none text-white">
              {@v}
              <span class="opacity-75">/</span>
              {@page.versions_count}
            </span>

            <.button
              disabled={@v == @page.versions_count}
              patch={~p"/#{@ctx.current_group.slug}/wiki/#{@page.slug}/v/#{@v + 1}"}
              class="btn btn-sm btn-circle btn-ghost"
            >
              <i class="hero-chevron-right size-4"></i>
            </.button>
          </div>

          <div class="text-xs flex justify-center gap-1.5">
            <WikWeb.Components.Time.pretty
              datetime={@version.occurred_at}
              class="opacity-80 hover:opacity-100 transition"
            />

            <span class="opacity-50">by</span>

            <.link class="opacity-80 hover:opacity-100 transition">
              {@author |> to_string()}
            </.link>
          </div>
        </div>
      </div>
      <%= if @version.data["text"] do %>
        <div
          id={"milkdown-editor-#{@v}"}
          phx-hook="MilkdownEditor"
          phx-update="ignore"
          data-markdown={@version.data["text"]}
          data-mode="static"
        />
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
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
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
