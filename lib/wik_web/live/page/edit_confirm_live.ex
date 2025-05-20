defmodule WikWeb.Page.EditConfirmLive do
  use WikWeb, :live_view
  alias Wik.Groups
  alias Wik.Page
  alias Wik.ResourceLockServer
  alias WikWeb.Page.ShowLive
  alias WikWeb.Page.EditLive
  require Logger

  def make_route(group_slug, slug), do: ~p"/#{group_slug}/wiki/#{slug}/edit/confirm"

  @impl true
  def mount(_params, session, socket) do
    socket = socket |> assign(:user, session["user"])
    {:ok, socket, layout: {WikWeb.Layouts, :fullscreen}}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => page_slug}, _uri, socket) do
    socket =
      socket
      |> assign(:group_slug, group_slug)
      |> assign(:slug, page_slug)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_edit", _params, socket) do
    group_slug = socket.assigns.group_slug
    slug = socket.assigns.slug
    user = socket.assigns.user
    ResourceLockServer.unlock(Page.resource_path(group_slug, slug), user.id)
    {:noreply, push_navigate(socket, to: EditLive.make_route(group_slug, slug))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto w-full self-center">
      <Layouts.card variant="warning">
        <div class="space-y-4">
          <p>It seems you are already editing this page in another tab.</p>
          <p>Are you sure you want to continue?</p>

          <.focus_wrap id="edit-confirm-actions" phx-hook="Phoenix.FocusWrap">
            <div class="flex justify-between">
              <Components.shortcut key="b">
                <.link
                  id="btn-cancel"
                  navigate={ShowLive.make_route(@group_slug, @slug)}
                  class="btn text-slate-700 font-bold bg-slate-300"
                  title="Go back"
                  autofocus
                >
                  <i class="hero-arrow-left-mini"></i>
                  <span>Go back</span>
                </.link>
              </Components.shortcut>

              <Components.shortcut key="e">
                <.link
                  id="btn-continue"
                  phx-click="confirm_edit"
                  class="btn text-orange-700 font-bold bg-orange-200"
                  title="Continue editing"
                >
                  <span>Edit anyway</span>
                  <i class="hero-arrow-right-mini"></i>
                </.link>
              </Components.shortcut>
            </div>
          </.focus_wrap>
        </div>
      </Layouts.card>
    </div>
    """
  end
end
