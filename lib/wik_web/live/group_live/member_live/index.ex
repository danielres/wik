defmodule WikWeb.GroupLive.MemberLive.Index do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer2 flash={@flash} ctx={@ctx}>
      <Layouts.page_container>
        <:title>Members</:title>

        <.table id="members" rows={@rels}>
          <:col :let={rel} label="Username">{rel.user |> to_string()}</:col>
          <:col :let={rel} label="Since">
            <WikWeb.Components.Time.pretty datetime={rel.inserted_at} />
          </:col>
        </.table>
      </Layouts.page_container>
    </Layouts.drawer2>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    rels =
      Wik.Accounts.GroupUserRelation
      |> Ash.Query.filter(group_id == ^socket.assigns.ctx.current_group.id)
      |> Ash.read!(actor: socket.assigns[:current_user], load: [:user])

    {:ok,
     socket
     |> assign(:page_title, "Listing Users")
     |> assign(:rels, rels)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end
end
