defmodule WikWeb.GroupLive.PageLive.Show do
  @moduledoc """
  LiveView for displaying a wiki page.

  Handles viewing wiki pages within a group, automatically creating pages
  that don't exist yet when accessed.
  """

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

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
          <WikWeb.Components.ButtonEdit.button
            :if={Ash.can?({@page, :update}, @current_user)}
            link={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/edit?return_to=show"}
            watch_path={@current_path <> "/edit"}
            presences={@ctx.presences}
          />
        </:actions>
      </.header>

      <.live_component
        module={WikWeb.Components.Generic.Modal}
        mandatory?
        id="user-tz-selector-modal"
        open?={@live_action == :edit and connected?(@socket)}
        phx-click-close={JS.patch(~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}")}
      >
        <.live_component
          module={WikWeb.Components.Page.Form}
          id={ "form-page-#{@page.id}" }
          page={@page}
          actor={@current_user}
          group={@ctx.current_group}
          return_to={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}"}
        >
        </.live_component>
      </.live_component>
      <main>{@page.text}</main>
    </Layouts.app>
    """
  end

  @doc """
  Retrieves a specific version of a page from the event history.

  ## Parameters
    - page_id: The ID of the page
    - version_number: The version number to retrieve (1-indexed)
    - actor: The actor performing the query (for authorization)

  ## Returns
    `{:ok, event}` or `{:error, reason}`
  """
  @spec get_page_version(String.t(), pos_integer(), Wik.Accounts.User.t()) ::
          {:ok, Wik.Versions.Version.t()} | {:error, term()}
  def get_page_version(page_id, version_number, actor) do
    require Ash.Query

    Wik.Versions.Version
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

  @impl true
  def handle_params(_params, url, socket) do
    WikWeb.Presence.track_in_liveview(socket, url)
    current_path = URI.parse(url).path
    socket = socket |> assign(current_path: current_path)

    socket =
      if socket.assigns.live_action == :edit do
        editors = socket.assigns.ctx.presences |> WikWeb.Presence.users_at_path(current_path)

        if editors |> length() > 0 do
          group_slug = socket.assigns.ctx.current_group.slug
          page_slug = socket.assigns.page.slug
          socket
          |> push_patch(to: ~p"/#{group_slug}/pages/#{page_slug}")
          |> Toast.put_toast(:info, "#{editors |> List.first()} is already editing this page")
        else
          socket
        end
      else
        socket
      end

    {:noreply, socket}
  end
end
