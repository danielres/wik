defmodule WikWeb.GroupLive.Form do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage group records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="group-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input type="text" field={@form[:title]} label="Title" />
        <.input type="text" field={@form[:text]} label="Short description" />

        <.button phx-disable-with="Saving..." variant="primary">Save Group</.button>
        <.button navigate={return_path(@return_to, @group)}>Cancel</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    group =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Wik.Accounts.Group, id, actor: socket.assigns.current_user)
      end

    action = if is_nil(group), do: "New", else: "Edit"
    page_title = action <> " " <> "Group"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(group: group)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"group" => group_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, group_params))}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: group_params) do
      {:ok, group} ->
        notify_parent({:saved, group})

        socket =
          socket
          |> put_flash(:info, "Group #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, group))

        {:noreply, socket}

      {:error, form} ->
        dbg(form.errors)
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{group: group}} = socket) do
    form =
      if group do
        AshPhoenix.Form.for_update(group, :update,
          as: "group",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Wik.Accounts.Group, :create,
          as: "group",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _group), do: ~p"/groups"
  defp return_path("show", group), do: ~p"/groups/#{group.id}"
end
