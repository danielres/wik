defmodule WikWeb.SuperAdmin.RevisionLive.FormComponent do
  use WikWeb, :live_component

  alias Wik.Revisions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage revision records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="revision-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:id]} type="text" label="Id" />
        <.input field={@form[:resource_path]} type="text" label="Resource path" />
        <.input field={@form[:patch]} type="text" label="Patch" />
        <.input field={@form[:user_id]} type="text" label="User id" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Revision</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{revision: revision} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Revisions.change_revision(revision))
     end)}
  end

  @impl true
  def handle_event("validate", %{"revision" => revision_params}, socket) do
    changeset = Revisions.change_revision(socket.assigns.revision, revision_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"revision" => revision_params}, socket) do
    save_revision(socket, socket.assigns.action, revision_params)
  end

  defp save_revision(socket, :edit, revision_params) do
    case Revisions.update_revision(socket.assigns.revision, revision_params) do
      {:ok, revision} ->
        notify_parent({:saved, revision})

        {:noreply,
         socket
         |> put_flash(:info, "Revision updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_revision(socket, :new, revision_params) do
    case Revisions.create_revision(revision_params) do
      {:ok, revision} ->
        notify_parent({:saved, revision})

        {:noreply,
         socket
         |> put_flash(:info, "Revision created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
