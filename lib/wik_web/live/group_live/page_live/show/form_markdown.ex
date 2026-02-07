defmodule WikWeb.GroupLive.PageLive.Show.FormMarkdown do
  use WikWeb, :live_component
  alias Wik.Wiki.PageTree.Markdown, as: Md
  alias Wik.Wiki.PageTree.Utils, as: Tree
  attr :undo_button_id, :string, default: nil
  attr :redo_button_id, :string, default: nil
  attr :exit_after_save?, :boolean, default: false
  attr :pages_tree_map, :map, default: %{}
  attr :page_tree_path, :string, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        class="space-y-8"
        id={@form_id || "page-form-#{@id}"}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
      >
        <% raw_text = @form[:text].value || @page.text || "" %>
        <% text_value = Md.rewrite_wikid_to_wikilinks(raw_text, @tree_by_id) %>

        <textarea id={"page_text_#{@id}"} name={@form[:text].name} hidden>{text_value}</textarea>

        <% page_title = Tree.title_from_path(@page_tree_path) %>

        <div class={"milkdown-editor-container editable-#{@editable}"}>
          <div
            id={"milkdown-editor-#{@id}"}
            phx-hook="MilkdownEditor"
            phx-update="ignore"
            data-markdown={text_value}
            data-page-title={page_title}
            data-page-id={@page.id}
            data-input-id={"page_text_#{@id}"}
            data-mode={if(@editable, do: "edit", else: "view")}
            data-undo-id={@undo_button_id}
            data-redo-id={@redo_button_id}
            data-user-meta={%{name: @actor |> to_string} |> Jason.encode!()}
            data-root-path={"/#{@group.slug}/wiki"}
            data-pages-json={@pages_json}
          />
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = socket |> assign(assigns) |> assign_form() |> assign_tree_maps()
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"page" => page_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, page_params))}
  end

  @impl true
  def handle_event("save", %{"page" => page_params}, socket) do
    path_map =
      ensure_page_tree_stubs(
        Map.get(page_params, "text"),
        socket.assigns.group.id,
        socket.assigns.actor,
        socket.assigns.pages_tree_map || %{}
      )

    page_params =
      Map.update(page_params, "text", "", fn text ->
        Md.rewrite_wikilinks_to_wikid(text, path_map)
      end)

    case AshPhoenix.Form.submit(socket.assigns.form, params: page_params) do
      {:ok, _page} ->
        socket =
          socket
          # |> push_navigate(to: socket.assigns.return_to)
          |> Toast.put_toast(:success, "Page #{socket.assigns.form.source.type}d successfully")

        if socket.assigns.exit_after_save? do
          send(self(), {:page_saved_for_exit, socket.assigns.page.id})
        end

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{page: page, group: group}} = socket) do
    form =
      if page do
        AshPhoenix.Form.for_update(page, :update,
          as: "page",
          actor: socket.assigns.actor
        )
      else
        AshPhoenix.Form.for_create(Wik.Wiki.Page, :create,
          as: "page",
          actor: socket.assigns.actor,
          context: %{shared: %{current_group_id: group.id}}
        )
      end

    assign(socket, form: to_form(form))
  end

  defp assign_tree_maps(socket) do
    pages_tree_map = socket.assigns.pages_tree_map || %{}
    values = Map.values(pages_tree_map)

    tree_by_id =
      values
      |> Enum.map(fn tree -> {tree.id, tree} end)
      |> Enum.into(%{})

    pages_json =
      values
      |> Enum.map(fn page ->
        {page.id,
         %{
           id: page.id,
           path: page.path,
           updated_at: page.updated_at
         }}
      end)
      |> Enum.into(%{})
      |> Jason.encode!()

    assign(socket, tree_by_id: tree_by_id, pages_json: pages_json)
  end

  defp ensure_page_tree_stubs(text, group_id, actor, path_map) do
    paths = Md.extract_wikilinks(text) |> Enum.map(& &1.target)

    Enum.reduce(paths, path_map, fn raw_path, map ->
      case Tree.resolve_tree_by_path(raw_path, group_id, actor, map) do
        {:ok, tree, next_map} ->
          _ = Tree.ensure_page_for_tree(tree, actor)
          next_map

        _ ->
          map
      end
    end)
  end
end
