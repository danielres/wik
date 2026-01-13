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
    <Layouts.drawer2 flash={@flash} ctx={@ctx}>
      <Layouts.page_container>
        <:title>
          <div class="flex items-center gap-1">
            <.link
              navigate={~p"/#{@ctx.current_group.slug}/tags"}
              class="opacity-75 hover:opacity-100 transition"
            >
              Tags
            </.link>

            <.icon name="hero-chevron-right-micro" class="size-6 opacity-30" />

            <WikWeb.Components.Tag.badge tag={@tag} size="xl" />
          </div>
        </:title>
        <div>
          <div :if={Enum.empty?(@tagged_blocks)} class="text-sm text-base-content/70 space-y-12">
            <p class="alert alert-info">
              No content found for this tag.
            </p>

            <section class="space-y-4">
              <h2 class="text-xl flex items-center gap-2">
                <i class="hero-question-mark-circle-mini opacity-80" /> How to
              </h2>

              <ul class="list-disc space-y-2 pl-4">
                <li>
                  <div class="flex items-baseline gap-2">
                    Add <span class="tag-badge">#{@tag.name}</span> to headers on various pages.
                  </div>
                </li>
                <li>
                  Content under those headers will show up here.
                </li>
              </ul>
            </section>

            <section class="space-y-4">
              <h2 class="text-xl flex items-center gap-2">
                <i class="hero-arrow-right-mini opacity-80" /> Example usage
              </h2>

              <div
                id={"milkdown-editor-#{@tag.name}"}
                phx-hook="MilkdownEditor"
                class="card p-4 bg-base-200"
                phx-update="ignore"
                data-markdown={@markdown}
                data-mode="static"
              />
            </section>
          </div>

          <div class="space-y-6">
            <section
              :for={{block_id, block} <- @tagged_blocks}
              id={"tag-block-#{block_id}"}
              class="bg-base-100 rounded shadow-lg border border-base-300"
            >
              <% page_path = page_tree_path_for(@ctx, block.page.id) %>
              <% base_url = WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, page_path) %>
              <h1 class="mb-4 bg-base-200 px-4 py-1 rounded-t flex items-center gap-2">
                <%= for {segment, idx} <- Enum.with_index(block.header_titles_stack) do %>
                  <%= if idx > 0 do %>
                    <.icon name="hero-chevron-right-micro" class="opacity-40" />
                  <% end %>

                  <.link
                    navigate={
                      if idx == 0 do
                        base_url
                      else
                        base_url <> "##{Enum.at(block.slug_stack, idx)}"
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
                class="[&_h1]:hidden px-4 [&_.milkdown-split-editor]:hidden"
                phx-update="ignore"
                data-markdown={block.markdown}
                data-mode="static"
                data-root-path={"/#{@ctx.current_group.slug}/wiki"}
              />
            </section>
          </div>
        </div>
      </Layouts.page_container>
    </Layouts.drawer2>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    markdown = """
    ## Hobbies #activities

    ### Crafting #activities/indoors

    - knitting
    - crafting

    ### Skydiving #activities/outdoors #skydiving

    - knitting while skydiving
    """

    {:ok,
     socket
     |> assign(:page_title, "Tag")
     |> assign(:markdown, markdown)
     |> assign_new(:tagged_blocks, fn -> [] end)}
  end

  @impl true
  def handle_params(%{"tag_name_segments" => tag_name_segments}, url, socket) do
    tag_name = tag_name_segments |> Enum.join("/")
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
        tag = %{name: tag_name}

        {:noreply,
         socket
         |> assign(:tag, tag)
         |> assign(:tagged_blocks, [])
         |> assign(:page_title, "Tag ##{tag.name}")}
    end
  end

  defp load_tag(socket, tag_name) do
    group_id = socket.assigns.ctx.current_group.id
    actor = socket.assigns.current_user
    downcased = String.downcase(tag_name)

    tag =
      Tag
      |> Ash.Query.filter(group_id == ^group_id and name == ^downcased)
      |> Ash.read!(actor: actor)
      |> case do
        [tag | _] -> tag
        _ -> nil
      end

    if is_nil(tag) do
      :not_found
    else
      tagged_blocks_per_page =
        PageToTag
        |> Ash.Query.filter(group_id == ^group_id and tag_id == ^tag.id)
        |> Ash.Query.load(page: [:text])
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

  defp page_tree_path_for(ctx, page_id) do
    case Map.get(ctx.pages_tree_by_page_id || %{}, page_id) do
      %{path: path} when is_binary(path) and path != "" -> path
      _ -> nil
    end
  end
end
