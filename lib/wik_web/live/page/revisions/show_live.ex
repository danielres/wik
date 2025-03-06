defmodule WikWeb.Page.Revisions.ShowLive do
  use WikWeb, :live_view

  alias Wik.Page
  alias Wik.Revisions

  def make_route(group_slug, page_slug, index),
    do: ~p"/#{group_slug}/wiki/#{page_slug}/revisions/#{index}"

  @impl true
  def mount(params, _session, socket) do
    group_slug = params["group_slug"]
    page_slug = params["slug"]
    index = params["index"]
    num_revisions = Page.resource_path(group_slug, page_slug) |> Revisions.count()

    socket =
      socket
      |> assign(:num_revisions, num_revisions)
      |> assign(group_slug: group_slug)
      |> assign(page_slug: page_slug)

    if index do
      {:ok, socket |> assign(:index, index |> Integer.parse() |> elem(0))}
    else
      {:ok, socket |> push_navigate(to: make_route(group_slug, page_slug, num_revisions))}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{"group_slug" => group_slug, "slug" => page_slug, "index" => index} = params
    index = index |> Integer.parse() |> elem(0)

    # TODO: optimize by applying patches in reverse order

    {:ok, raw} = Page.load_at(group_slug, page_slug, index - 1)
    previous_html = Page.render(group_slug, raw)

    {:ok, raw} = Page.load_at(group_slug, page_slug, index)
    current_html = Page.render(group_slug, raw)

    {:noreply,
     socket
     |> assign(:content, current_html)
     |> assign(:previous_content, previous_html)}
  end

  @impl true
  def handle_event(event, _params, socket) when event in ["prev", "next"] do
    %{index: index, group_slug: group_slug, page_slug: page_slug} = socket.assigns
    new_index = if event == "prev", do: index - 1, else: index + 1

    {:noreply,
     socket
     |> assign(:index, new_index)
     |> push_patch(to: make_route(group_slug, page_slug, new_index))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4 max-w-screen-md mx-auto">
      <div class="flex justify-between items-end gap-4">
        <h1 class="text-xl text-slate-700 grid gap-2 items-end">
          {@page_slug}
        </h1>

        <div class="space-y-2">
          <div class="flex justify-end">
            <div data-test-id="revisions-counter" class="revisions badge badge-info">
              Version <span class="current" data-test-id="index">{@index}</span>
              <span class="separator">/</span>
              <span class="total" data-test-id="total">{@num_revisions}</span>
            </div>
          </div>

          <div class="flex gap-2">
            <Components.shortcut key="b">
              <.link href={~p"/#{@group_slug}/wiki/#{@page_slug}"} class="btn btn-ghost">
                Back
              </.link>
            </Components.shortcut>
            <Components.shortcut key="p">
              <button
                phx-click="prev"
                class="btn btn-primary"
                disabled={@num_revisions == 0 || @index == 1}
                data-test-id="action-prev"
              >
                Prev
              </button>
            </Components.shortcut>
            <Components.shortcut key="n">
              <button
                phx-click="next"
                class="btn btn-primary"
                disabled={@num_revisions == 0 || @index == @num_revisions}
                data-test-id="action-next"
              >
                Next
              </button>
            </Components.shortcut>
          </div>
        </div>
      </div>

      <div>
        <div tabindex="1" class="bg-slate-50 p-4 md:p-8 rounded shadow">
          <Components.prose>
            <div id="html_differ" phx-hook="HtmlDiffer">
              <div class="hidden" id="html_differ-original" data-test-id="revisions-original">
                {raw(@previous_content)}
              </div>
              <div class="hidden" id="html_differ-revised" data-test-id="revisions-revised">
                {raw(@content)}
              </div>
              <div class="diff" id="html_differ-diff"></div>
            </div>
            <hr />
          </Components.prose>
        </div>
      </div>
    </div>
    """
  end
end
