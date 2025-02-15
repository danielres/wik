defmodule WikWeb.Page.EditLive do
  use WikWeb, :live_view
  alias Wik.{Page, ResourceLockServer}
  require Logger

  @impl true
  def mount(_params, session, socket) do
    user = session["user"] || %{}

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:group_slug, nil)
     |> assign(:slug, nil)
     |> assign(:group_title, nil)
     |> assign(:edit_content, nil)
     |> assign(:suggestions, []), layout: {WikWeb.Layouts, :fullscreen}}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => slug}, _uri, socket) do
    # Assign group_title first, as it depends only on group_slug
    group_title = Wik.get_group_title(group_slug)

    socket =
      socket
      |> assign(:group_slug, group_slug)
      |> assign(:slug, slug)
      |> assign(:group_title, group_title)
      |> assign(:resource_path, "#{group_slug}/wiki/#{slug}")

    case Page.load(group_slug, slug) do
      {:ok, content} ->
        {:noreply, assign(socket, edit_content: content)}

      :not_found ->
        {:noreply, assign(socket, edit_content: "")}
    end
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
    Page.save(group_slug, slug, new_content)
    user = socket.assigns.user
    ResourceLockServer.unlock("#{group_slug}/wiki/#{slug}", user.id)
    {:noreply, push_navigate(socket, to: ~p"/#{group_slug}/wiki/#{slug}")}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    group_slug = socket.assigns.group_slug
    slug = socket.assigns.slug
    user = socket.assigns.user
    ResourceLockServer.unlock("#{group_slug}/wiki/#{slug}", user.id)
    {:noreply, push_navigate(socket, to: ~p"/#{group_slug}/wiki/#{slug}")}
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
    <div
      data-shortcuts="page_edit"
      id="edit_live"
      class="space-y-4 grid grid-rows-[auto,1fr] max-w-2xl "
    >
      <div class="flex justify-between items-end">
        <h1 class="text-xl text-slate-700">{@slug || "Untitled"}</h1>
        <div class="flex gap-4">
          <button
            tabindex="3"
            type="cancel"
            class="btn btn-secondary"
            phx-click="cancel_edit"
            phx-hook="AddKeyboardShortcut"
            id="button-cancel-edit"
          >
            Cancel
          </button>
          <button
            tabindex="2"
            form="edit-form"
            type="submit"
            class="btn btn-primary"
            phx-hook="AddKeyboardShortcut"
            id="button-save-edit"
          >
            Save
          </button>
        </div>
      </div>

      <form
        id="edit-form"
        data-resource-path={"#{@group_slug}/wiki/#{@slug}"}
        data-user-id={@user.id}
        data-user-name={@user.username}
        phx-submit="update_page"
        class="focus-within:ring-2 rounded bg-white shadow grid grid-rows-[auto,1fr]"
      >
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
        <textarea
          phx-hook="ShowSuggestionsOnKeyup"
          id="edit-textarea"
          phx-mounted={JS.focus()}
          tabindex="1"
          name="content"
          class="w-full border-t-0 bg-white focus:ring-0 rounded-b border-none pointer-events-auto "
        ><%= @edit_content %></textarea>
      </form>
    </div>
    """
  end
end
