defmodule WikWeb.Page.Revisions.ShowLive do
  use WikWeb, :live_view

  alias Wik.Page
  alias Wik.Revisions

  def make_route(group_slug, page_slug, index),
    do: ~p"/#{group_slug}/wiki/#{page_slug}/revisions/#{index}"

  @impl true
  def mount(params, session, socket) do
    user = session["user"]
    group_slug = params["group_slug"]
    page_slug = params["slug"]
    index = params["index"]
    num_revisions = Page.resource_path(group_slug, page_slug) |> Revisions.count()

    socket =
      socket
      |> assign(:user, user)
      |> assign(:num_revisions, num_revisions)
      |> assign(group_slug: group_slug)
      |> assign(page_slug: page_slug)
      |> assign(:group_name, Wik.get_group_name(group_slug))

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

    {:ok, raw} = Page.load_at(group_slug, page_slug, index - 1)
    previous_html = Page.render(group_slug, raw)

    {:ok, raw} = Page.load_at(group_slug, page_slug, index)
    current_html = Page.render(group_slug, raw)

    # TODO: trim markdown when saving instead
    current_markdown = raw |> String.trim()

    {:noreply,
     socket
     |> assign(:markdown, current_markdown)
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
    <Layouts.app_layout>
      <:header_left>
        <a
          href={~p"/#{@group_slug}"}
          class="flex text-slate-500 hover:text-slate-600"
          style="font-variant: small-caps"
        >
          {@group_name}
        </a>
      </:header_left>

      <:header_right>
        <Components.avatar user_photo_url={@user.photo_url} />
      </:header_right>

      <:menu>
        <div class="flex justify-between items-end">
          <div class="flex gap-4 ">
            <Components.shortcut
              key="b"
              class="flex items-center bg-slate-300 rounded-full px-1 py-1 opacity-50 hover:opacity-100"
            >
              <.link
                title="Back"
                href={~p"/#{@group_slug}/wiki/#{@page_slug}"}
                class="hero-arrow-left-mini"
              >
                Back
              </.link>
            </Components.shortcut>
            <Layouts.page_slug group_slug={@group_slug} page_slug={@page_slug} />
          </div>

          <div class="badge badge-info">
            <div class="flex gap-1 items-center py-1 px-0.5">
              <Components.shortcut key="p">
                <button
                  phx-click="prev"
                  class="btn hero-chevron-left disabled:opacity-0"
                  disabled={@num_revisions == 0 || @index == 1}
                  data-test-id="action-prev"
                  title="Previous version"
                >
                  Prev
                </button>
              </Components.shortcut>

              <div class="flex justify-end">
                <div data-test-id="revisions-counter" class="text-sm">
                  Version
                  <span data-test-id="index">
                    {@index}
                  </span>
                  <span class="separator">/</span>
                  <span class="total" data-test-id="total">{@num_revisions}</span>
                </div>
              </div>

              <Components.shortcut key="n">
                <button
                  phx-click="next"
                  class="btn hero-chevron-right disabled:opacity-0"
                  disabled={@num_revisions == 0 || @index == @num_revisions}
                  data-test-id="action-next"
                  title="Next version"
                >
                  Next
                </button>
              </Components.shortcut>
            </div>
          </div>
        </div>
      </:menu>

      <:main>
        <div class="grid">
          <div tabindex="1" class="bg-slate-50 p-4 md:p-8 rounded shadow relative">
            <div class="absolute top-3 right-3 ">
              <Components.toggle_source_button phx-click={
                JS.toggle(to: "#html_differ-diff")
                |> JS.toggle(to: "#markdown-source")
              } />
            </div>
            <Components.prose>
              <div id="html_differ" phx-hook="HtmlDiffer">
                <div class="hidden font-mono whitespace-pre-line" id="markdown-source">
                  {raw(@markdown)}
                </div>

                <div class="hidden" id="html_differ-original" data-test-id="revisions-original">
                  {raw(@previous_content)}
                </div>

                <div class="hidden" id="html_differ-revised" data-test-id="revisions-revised">
                  {raw(@content)}
                </div>

                <div class="diff" id="html_differ-diff"></div>
              </div>
            </Components.prose>
          </div>
        </div>
      </:main>
    </Layouts.app_layout>
    """
  end
end
