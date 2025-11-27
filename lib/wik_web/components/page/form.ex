defmodule WikWeb.Components.Page.Form do
  use WikWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} id="page-form" phx-change="validate" phx-submit="save" phx-target={@myself}>
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:text]} type="textarea" label="Text" />
        <.input field={@form[:slug]} type="text" label="Slug" />

        <.button phx-disable-with="Saving..." variant="primary">Save Page</.button>
        <.button patch={@return_to}>Cancel</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = socket |> assign(assigns) |> assign_form()
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"page" => page_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, page_params))}
  end

  def handle_event("save", %{"page" => page_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: page_params) do
      {:ok, _page} ->
        socket =
          socket
          |> push_navigate(to: socket.assigns.return_to)
          |> Toast.put_toast(:success, "Page #{socket.assigns.form.source.type}d successfully")

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
          actor: socket.assigns.current_user,
          context: %{shared: %{current_group_id: group.id}}
        )
      end

    assign(socket, form: to_form(form))
  end
end
