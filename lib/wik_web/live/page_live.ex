defmodule WikWeb.PageLive do
  use WikWeb, :live_view

  alias Wik.{Page, Wiki}
  alias Wik.ResourceLockServer

  @impl true
  def mount(_params, session, socket) do
    # Extract the logged-in user from the session.
    user = session["user"] || %{}

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:group_slug, nil)
     |> assign(:slug, nil)
     |> assign(:group_title, nil)
     |> assign(:content, nil)
     |> assign(:backlinks, [])
     |> assign(:editing, false)
     |> assign(:edit_content, nil)}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "slug" => slug}, _uri, socket) do
    group_title = Wik.get_group_title(group_slug)

    case Page.load(group_slug, slug) do
      {:ok, content} ->
        rendered = Wiki.render(group_slug, content)
        backlinks = Page.backlinks(group_slug, slug)

        {:noreply,
         socket
         |> assign(:group_slug, group_slug)
         |> assign(:slug, slug)
         |> assign(:group_title, group_title)
         |> assign(:content, rendered)
         |> assign(:backlinks, backlinks)
         |> assign(:editing, false)}

      :not_found ->
        {:noreply,
         socket
         |> assign(:group_slug, group_slug)
         |> assign(:slug, slug)
         |> assign(:group_title, group_title)
         |> assign(:content, nil)
         |> assign(:backlinks, [])
         |> assign(:editing, true)}
    end
  end

  # When only group_slug is provided, default slug to "home"
  def handle_params(%{"group_slug" => _group_slug} = params, uri, socket) do
    handle_params(Map.put(params, "slug", "home"), uri, socket)
  end

  @impl true
  def handle_event("edit_page", %{"slug" => page_slug}, socket) do
    group_slug = socket.assigns.group_slug
    resource_path = "#{group_slug}/wiki/#{page_slug}"
    user = socket.assigns.user

    case ResourceLockServer.lock(resource_path, user.id) do
      :ok ->
        # Load the raw content for editing.
        case Page.load(group_slug, page_slug) do
          {:ok, content} ->
            {:noreply, assign(socket, editing: true, edit_content: content)}

          :not_found ->
            {:noreply, assign(socket, editing: true, edit_content: "")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
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

  # Release the lock when the LiveView process terminates.
  @impl true
  def terminate(_reason, socket) do
    if socket.assigns.editing do
      ResourceLockServer.unlock(
        "#{socket.assigns.group_slug}/wiki/#{socket.assigns.slug}",
        socket.assigns.user.id
      )
    end

    IO.inspect(socket.assigns, label: "TERMINATE")

    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-end">
        <h1 class="text-xl text-slate-700">{@slug}</h1>
        <%= if @editing do %>
          <button tabindex="2" form="edit-form" type="submit" class="btn btn-primary">
            Save
          </button>
        <% else %>
          <button
            tabindex="2"
            phx-click="edit_page"
            phx-value-slug={@slug}
            class="btn btn-primary mt-4"
          >
            Edit
          </button>
        <% end %>
      </div>

      <div>
        <%= if @editing do %>
          <div>
            <form
              id="edit-form"
              data-resource-path={"#{@group_slug}/wiki/#{@slug}"}
              data-user-id={@user.id}
              data-user-name={@user.username}
              phx-hook="ResourceLock"
              phx-submit="update_page"
            >
              <textarea phx-mounted={JS.focus()} tabindex="1" name="content" class="w-full h-96"><%= @edit_content %></textarea>
            </form>
          </div>
        <% else %>
          <div tabindex="1" class="bg-slate-50 p-4 md:p-8 rounded shadow">
            <div
              :if={@backlinks && length(@backlinks) > 0}
              class="float-right bg-white border p-6 py-5 rounded space-y-2 ml-8 mb-8 max-w-52 overflow-hidden"
            >
              <h2 class="text-xs font-semibold text-slate-500">Backlinks</h2>
              <ul class="text-sm space-y-2">
                <%= for backlink <- @backlinks do %>
                  <li>
                    <a
                      class="text-blue-600 hover:underline opacity-75 hover:opacity-100 leading-none block"
                      href={~p"/#{@group_slug}/wiki/#{backlink}"}
                    >
                      {backlink}
                    </a>
                  </li>
                <% end %>
              </ul>
            </div>

            <div class="prose prose-sm prose-a:text-blue-600 prose-a:no-underline hover:prose-a:underline prose-headings:text-slate-600 ">
              {raw(@content)}
            </div>

            <div class="clear-both"></div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
