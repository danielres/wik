defmodule WikWeb.TagLive.Index do
  @moduledoc """
  Lists tags for the current group.

  Tags are extracted from header hashtags in wiki pages; this view is read-only.
  """

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  alias Wik.Tags.Tag

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.drawer2 flash={@flash} ctx={@ctx}>
      <Layouts.page_container>
        <:title>Tags</:title>

        <ul :if={Enum.any?(@tags)} id="tags" class="space-y-4">
          <li :for={tag <- @tags} id={"tag-#{tag.id}"} class="grid grid-cols-2">
            <WikWeb.Components.Tag.badge tag={tag} ctx={@ctx} />

            <span class="flex items-center gap-1 text-xs opacity-80">
              <i class="hero-document-micro size-4 opacity-80">
                page{(tag.pages_count != 1 && "s") || ""}
              </i>
              {tag.pages_count || 0}
            </span>
          </li>
        </ul>

        <div
          :if={Enum.empty?(@tags)}
          class="text-base-content/70 card bg-base-200 p-4 text-center my-8"
        >
          <p>No tags found yet.</p>
          <p>Add hashtags to headings in wiki pages to use this feature.</p>
        </div>
      </Layouts.page_container>
    </Layouts.drawer2>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_group = socket.assigns.ctx.current_group
    current_user = socket.assigns.ctx.current_user

    tags = get_group_tags(current_group, current_user)

    {:ok,
     socket
     |> assign(:page_title, "Tags")
     |> assign(:tags, tags)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)
    {:noreply, socket}
  end

  defp get_group_tags(group, actor) do
    Tag
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.load([:pages_count])
    |> Ash.Query.filter(pages_count > 0)
    |> Ash.Query.sort(:name)
    |> Ash.read!(actor: actor)
  end
end
