defmodule WikWeb.Components.Group.Form do
  use WikWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="group-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <.input type="text" field={@form[:title]} label="Title" />
        <.input type="text" field={@form[:text]} label="Short description" />

        <.button phx-disable-with="Saving..." variant="primary">Save Group</.button>
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
  def handle_event("validate", %{"group" => group_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, group_params))}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: group_params) do
      {:ok, _group} ->
        socket =
          socket
          |> push_patch(to: socket.assigns.return_to)
          |> Toast.put_toast(:success, "Group #{socket.assigns.form.source.type}d successfully")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{group: group}} = socket) do
    form =
      if group do
        AshPhoenix.Form.for_update(group, :update,
          as: "group",
          actor: socket.assigns.actor
        )
      else
        AshPhoenix.Form.for_create(Wik.Accounts.Group, :create,
          as: "group",
          actor: socket.assigns.actor
        )
      end

    assign(socket, form: to_form(form))
  end
end
