defmodule WikWeb.Page.EditLive do
  use WikWeb, :live_view
  alias Wik.{Page, ResourceLockServer}
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
  def handle_params(%{"group_slug" => group_slug, "slug" => slug}, _uri, socket) do
    props =
      case Page.load(group_slug, slug) do
        {:ok, {metadata, body}} ->
          %{page_title: metadata["title"], metadata: metadata, edit_content: body}

        :not_found ->
          %{page_title: String.capitalize(slug), metadata: %{}, edit_content: ""}
      end

    {
      :noreply,
      socket
      |> assign(props)
      |> assign(:group_slug, group_slug)
      |> assign(:slug, slug)
      |> assign(:group_title, Wik.get_group_title(group_slug))
      |> assign(:resource_path, Page.resource_path(group_slug, slug))
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
  def handle_event("update_page", %{"content" => new_content, "metadata" => new_metadata}, socket) do
    group_slug = socket.assigns.group_slug
    slug = socket.assigns.slug
    user = socket.assigns.user

    metadata =
      case Page.load(group_slug, slug) do
        :not_found ->
          %{title: String.capitalize(slug)}

        {:ok, document} ->
          {metadata, _body} = document
          Map.merge(metadata, new_metadata)
      end

    Page.save(group_slug, slug, new_content, metadata)
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
    <div id="edit_live" class="space-y-4 grid grid-rows-[auto,1fr] max-w-2xl ">
      <div class="flex justify-between items-end">
        <h1 class="text-xl text-slate-700">{@page_title}</h1>
        <div class="flex gap-4">
          <button phx-click="cancel_edit" tabindex="3" type="cancel" class="btn btn-secondary">
            Cancel
          </button>
          <button
            phx-hook="SetShortcut"
            phx-hook-shortcut-key="s"
            id="button-save-edit"
            tabindex="2"
            form="edit-form"
            type="submit"
            class="btn btn-primary"
          >
            Save
          </button>
        </div>
      </div>

      <form
        id="edit-form"
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
        <input type="hidden" name="metadata[title]" value={@page_title} />
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
