defmodule WikWeb.GroupLive.PageLive.History do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  def page_url(group, page, version) do
    "/#{group.slug}/v/#{version}/wiki/#{page.slug}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer flash={@flash} ctx={@ctx}>
      <:sticky_toolbar>
        <div class="toolbar-editor-controls">
          <div class="space-y-1">
            <div class="flex gap-2 items-start">
              <div>
                <div class="toolbar-actions items-center text-xs">
                  <.link
                    class={["action", @v == 1 and "action-disabled"]}
                    patch={if @v == 1, do: "#", else: page_url(@ctx.current_group, @page, 1)}
                    aria-disabled={@v == 1}
                    tabindex={@v == 1 && "-1"}
                  >
                    <.icon name="hero-chevron-double-left-mini" />
                  </.link>
                  <.link
                    class={["action", @v == 1 and "action-disabled"]}
                    patch={if @v > 1, do: page_url(@ctx.current_group, @page, @v - 1), else: "#"}
                    aria-disabled={@v == 1}
                    tabindex={@v == 1 && "-1"}
                  >
                    <.icon name="hero-chevron-left-mini" />
                  </.link>
                  <div class="whitespace-nowrap min-w-16 text-center">
                    <span>{@v}</span>
                    <span class="opacity-60">/</span>
                    <span class="opacity-60">{@page.versions_count}</span>
                  </div>
                  <.link
                    patch={
                      if @v < @page.versions_count,
                        do: page_url(@ctx.current_group, @page, @v + 1),
                        else: "#"
                    }
                    class={["action", @v == @page.versions_count and "action-disabled"]}
                    aria-disabled={@v == @page.versions_count}
                    tabindex={@v == @page.versions_count && "-1"}
                  >
                    <.icon name="hero-chevron-right-mini" />
                  </.link>
                  <.link
                    patch={page_url(@ctx.current_group, @page, @page.versions_count)}
                    class={["action", @v == @page.versions_count and "action-disabled"]}
                    aria-disabled={@v == @page.versions_count}
                    tabindex={@v == @page.versions_count && "-1"}
                  >
                    <.icon name="hero-chevron-double-right-mini" />
                  </.link>
                </div>

                <div class="text-end text-xs px-2 pt-1 opacity-80 hover:opacity-100 transition">
                  <div>
                    <WikWeb.Components.Time.pretty
                      datetime={@version.occurred_at}
                      class="opacity-80 hover:opacity-100 transition"
                    />
                    <span class="opacity-50">by</span>

                    {# TODO: link to author }
                    <.link class="opacity-80 hover:opacity-100 transition">
                      {@author |> to_string()}
                    </.link>
                  </div>
                </div>
              </div>

              <div class="toolbar-actions ">
                <.link
                  class="action !btn-ghost opacity-40 hover:opacity-100 transition"
                  patch={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, @page)}
                >
                  <.icon name="hero-x-mark size-6" />
                </.link>
              </div>
            </div>
          </div>
        </div>
      </:sticky_toolbar>

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
    </Layouts.drawer>
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

  def mount(%{"page_slug_segments" => page_slug_segments}, _session, socket) do
    page_slug = page_slug_segments |> Enum.join("/")

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
