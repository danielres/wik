defmodule WikWeb.Page.EditLive do
  use WikWeb, :live_view
  alias Wik.Page
  alias Wik.ResourceLockServer
  require Logger

  defp page_path(group_slug, slug), do: ~p"/#{group_slug}/wiki/#{slug}"

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:user, session["user"])
     |> assign(:suggestions, []), layout: {WikWeb.Layouts, :fullscreen}}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => page_slug}, _uri, socket) do
    props =
      case Page.load(group_slug, page_slug) do
        {:ok, {metadata, body}} ->
          %{page_title: page_slug, metadata: metadata, edit_content: body}

        :not_found ->
          %{page_title: page_slug, metadata: %{}, edit_content: ""}
      end

    {
      :noreply,
      socket
      |> assign(props)
      |> assign(:group_slug, group_slug)
      |> assign(:slug, page_slug)
      # TODO: move get_group_name to Groups context
      |> assign(:group_name, Wik.get_group_name(group_slug))
      |> assign(:resource_path, Page.resource_path(group_slug, page_slug))
    }
  end

  @impl true
  def handle_event("suggest", %{"term" => term}, socket) do
    group_slug = socket.assigns.group_slug
    suggestions = Page.suggestions(group_slug, term)
    {:noreply, assign(socket, suggestions: suggestions)}
  end

  @impl true
  def handle_event("select_suggestion", _params, socket) do
    {:noreply, assign(socket, suggestions: [])}
  end

  @impl true
  def handle_event("update_page", %{"content" => new_content}, socket) do
    group_slug = socket.assigns.group_slug
    slug = socket.assigns.slug
    user = socket.assigns.user

    metadata =
      case Page.load(group_slug, slug) do
        :not_found ->
          %{title: slug}

        {:ok, document} ->
          {metadata, _body} = document
          metadata
      end

    Page.save(user.id, group_slug, slug, new_content, metadata)
    ResourceLockServer.unlock(Page.resource_path(group_slug, slug), user.id)
    msg = {:page_updated, user, group_slug, slug, new_content}
    Phoenix.PubSub.broadcast(Wik.PubSub, "pages", msg)
    {:noreply, push_navigate(socket, to: page_path(group_slug, slug))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    group_slug = socket.assigns.group_slug
    slug = socket.assigns.slug
    user = socket.assigns.user
    ResourceLockServer.unlock(Page.resource_path(group_slug, slug), user.id)
    {:noreply, push_navigate(socket, to: page_path(group_slug, slug))}
  end

  @impl true
  def terminate(reason, socket) do
    resource_path = socket.assigns.resource_path
    user_id = socket.assigns.user.id
    ResourceLockServer.unlock(resource_path, user_id)
    Logger.debug("Unlocked #{resource_path}. Reason: #{inspect(reason)}")
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form
      class="space-y-4 grid grid-rows-[auto,1fr] max-w-2xl mx-auto w-full"
      id="edit-form"
      phx-submit="update_page"
      phx-hook="Phoenix.FocusWrap"
    >
      <div class="flex justify-between items-end gap-2" tabindex="0">
        <Layouts.page_slug group_slug={@group_slug} page_slug={@page_title} />

        <div class="flex gap-2">
          <Components.shortcut key="c">
            <button phx-click="cancel_edit" tabindex="3" type="cancel" class="btn btn-ghost">
              Cancel
            </button>
          </Components.shortcut>

          <Components.shortcut key="s">
            <button tabindex="2" form="edit-form" type="submit" class="btn btn-primary">
              Save
            </button>
          </Components.shortcut>
        </div>
      </div>

      <div class="rounded shadow grid grid-rows-[auto,1fr] [&_ul]:opacity-60 [&_textarea]:opacity-60 [&:focus-within_ul]:opacity-100 [&:focus-within_textarea]:opacity-100 ">
        <ul
          class="flex overflow-x-auto bg-slate-100 rounded-t p-2 [&>li.active]:bg-blue-400"
          id="suggestions-list"
        >
          <li class="spacer opacity-0 w-0 border pointer-events-none">spacer</li>
          <li
            :for={suggestion <- @suggestions}
            :if={length(@suggestions) > 0}
            phx-click="select_suggestion"
            phx-value={suggestion}
            phx-hook="SelectSuggestion"
            phx-value-target="edit-textarea"
            id={"suggestion-#{suggestion}"}
            class={"cursor-pointer bg-blue-100 hover:bg-blue-300 text-nowrap px-2 mr-4 pointer-events-auto #{if suggestion == Enum.at(@suggestions, 0), do: "active", else: ""}"}
          >
            {suggestion}
          </li>
        </ul>
        <Components.shortcut key="b" class="grid">
          <textarea
            phx-hook="ShowSuggestionsOnKeyup"
            id="edit-textarea"
            phx-mounted={JS.focus()}
            tabindex="1"
            name="content"
            class="w-full border-t-0 focus:ring-0 rounded-b border-none pointer-events-auto "
          ><%= @edit_content %></textarea>
        </Components.shortcut>
      </div>
    </form>
    """
  end
end
