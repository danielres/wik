defmodule WikWeb.TagLive.Show do
  @moduledoc """
  Shows a single tag and the pages that use it within the current group.
  """

  use WikWeb, :live_view
  use WikWeb.Presence.Handlers
  require Ash.Query

  alias Utils.Markdown
  alias Wik.Tags.{PageToTag, Tag}

  @headings_base_level 1

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        <div class="flex items-center gap-1">
          <.link
            navigate={~p"/#{@ctx.current_group.slug}/tags"}
            class="opacity-75 hover:opacity-100 transition"
          >
            Tags
          </.link>
          <i class="hero-chevron-right-micro size-6 opacity-50" />
          <span class="badge badge-neutral badge-xl">#{:"#{@tag.name}"}</span>
        </div>
        <:actions></:actions>
      </.header>

      <div class="space-y-4">
        <div :if={Enum.empty?(@tagged_blocks)} class="text-sm text-base-content/70">
          No tagged blocks found yet.
        </div>

        <div class="space-y-4 mt-8">
          <section
            :for={{block_id, block} <- @tagged_blocks}
            id={"tag-block-#{block_id}"}
            class="bg-base-100 rounded shadow-lg border border-base-300 "
          >
            <h1 class="mb-4 bg-base-200 px-4 py-1 rounded-t flex items-center gap-2">
              <%= for {segment, idx} <- Enum.with_index(block.header_titles_stack) do %>
                <%= if idx > 0 do %>
                  <i class="hero-chevron-right-micro size-4 opacity-50">/</i>
                <% end %>

                <.link
                  navigate={
                    if idx == 0 do
                      ~p"/#{@ctx.current_group.slug}/wiki/#{block.page.slug}"
                    else
                      "/#{@ctx.current_group.slug}/wiki/#{block.page.slug}##{Enum.at(block.slug_stack, idx)}"
                    end
                  }
                  class={[
                    "opacity-75 hover:opacity-100 transition text-sm",
                    idx == 0 && "font-semibold opacity-85"
                  ]}
                >
                  {segment}
                </.link>
              <% end %>
            </h1>

            <div
              id={"md-block-#{block_id}"}
              phx-hook="MilkdownEditor"
              class="[&_h1]:hidden px-4"
              phx-update="ignore"
              data-markdown={block.markdown}
              data-mode="static"
              data-root-path={"/#{@ctx.current_group.slug}/wiki"}
            />
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Tag")}
  end

  @impl true
  def handle_params(%{"tag_name" => tag_name}, url, socket) do
    socket = Utils.Ctx.add(socket, :current_path, URI.parse(url).path)
    WikWeb.Presence.track_in_liveview(socket, url)

    case load_tag(socket, tag_name) do
      {:ok, tag, tagged_blocks_per_page} ->
        tagged_blocks = prepare_blocks(tagged_blocks_per_page)

        {:noreply,
         socket
         |> assign(:tag, tag)
         |> assign(:tagged_blocks, tagged_blocks)
         |> assign(:page_title, "Tag ##{tag.name}")}

      :not_found ->
        {:noreply,
         socket
         |> put_flash(:error, "Tag not found")
         |> push_navigate(to: ~p"/#{socket.assigns.ctx.current_group.slug}/tags")}
    end
  end

  defp load_tag(socket, tag_name) do
    group_id = socket.assigns.ctx.current_group.id
    actor = socket.assigns.current_user
    downcased = String.downcase(tag_name)

    tag =
      Tag
      |> Ash.Query.filter(group_id == ^group_id and name == ^downcased)
      |> Ash.read(actor: actor)
      |> case do
        {:ok, [tag | _]} -> tag
        _ -> nil
      end

    if is_nil(tag) do
      :not_found
    else
      tagged_blocks_per_page =
        PageToTag
        |> Ash.Query.filter(group_id == ^group_id and tag_id == ^tag.id)
        |> Ash.Query.load(page: [:title, :slug, :text])
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(actor: actor)
        |> Enum.map(fn rel ->
          blocks =
            Markdown.extract_tagged_blocks(rel.page.text || "", tag.name,
              headings_base_level: @headings_base_level
            )

          %{page: rel.page, blocks: blocks}
        end)
        |> Enum.reject(fn %{blocks: blocks} -> blocks == [] end)

      {:ok, tag, tagged_blocks_per_page}
    end
  end

  defp prepare_blocks(tagged_blocks_per_page) do
    # - flattens page-grouped blocks
    # - adds stable ids 
    # - adds fields needed for rendering
    tagged_blocks_per_page
    |> Enum.flat_map(fn %{page: page, blocks: blocks} ->
      blocks
      |> Enum.with_index()
      |> Enum.map(fn block_with_idx -> prepare_block(page, block_with_idx) end)
    end)
  end

  defp prepare_block(page, {block, idx}) do
    id = "#{page.id}-#{idx}"
    {id, Map.put(block, :page, page)}
  end
end
