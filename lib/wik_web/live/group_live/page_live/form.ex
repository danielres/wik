defmodule WikWeb.GroupLive.PageLive.Form do
  use WikWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} ctx={@ctx}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage page records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="page-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:text]} type="text" label="Text" />
        <.input field={@form[:slug]} type="text" label="Slug" />

        <.button phx-disable-with="Saving..." variant="primary">Save Page</.button>
        <.button navigate={
          if @page,
            do: ~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}",
            else: ~p"/#{@ctx.current_group.slug}/pages"
        }>
          Cancel
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    page =
      case params["page_slug"] do
        nil ->
          nil

        page_slug ->
          Wik.Wiki.Page
          |> Ash.get!(
            %{group_id: socket.assigns.ctx.current_group.id, slug: page_slug},
            actor: socket.assigns.current_user
          )
      end

    action = if is_nil(page), do: "New", else: "Edit"
    page_title = action <> " " <> "Page"
    dbg(socket.assigns.ctx.current_group)

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(page: page)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"page" => page_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, page_params))}
  end

  def handle_event("save", %{"page" => page_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: page_params) do
      {:ok, page} ->
        notify_parent({:saved, page})

        path =
          case socket.assigns.return_to do
            "show" -> ~p"/#{socket.assigns.ctx.current_group.slug}/pages/#{page.slug}"
            _ -> ~p"/#{socket.assigns.ctx.current_group.slug}/pages"
          end

        socket =
          socket
          |> put_flash(:info, "Page #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: path)

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{page: page, ctx: ctx}} = socket) do
    form =
      if page do
        AshPhoenix.Form.for_update(page, :update,
          as: "page",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Wik.Wiki.Page, :create,
          as: "page",
          actor: socket.assigns.current_user,
          context: %{shared: %{current_group_id: ctx.current_group.id}}
        )
      end

    assign(socket, form: to_form(form))
  end
end
