defmodule WikWeb.Components.Generic.Modal do
  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign_new(:open?, fn -> false end)
      |> assign(assigns)

    {:ok, socket}
  end

  slot :trigger
  slot :inner_block
  attr :padding_class, :string, default: "p-6"
  attr :"phx-click-close", :any, default: nil
  attr :mandatory?, :boolean, default: false
  attr :open?, :boolean, default: false

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <span role="button" phx-click="open" phx-target={@myself}>
        {render_slot(@trigger)}
      </span>

      <dialog
        id={@id}
        class="modal text-base font-normal"
        open={@open?}
        phx-window-keydown={!@mandatory? && "close"}
        phx-key="escape"
        phx-target={@myself}
      >
        <div
          class={"modal-box bg-base-100 #{@padding_class}"}
          phx-target={@myself}
          phx-capture-click
          phx-click-away={@open? && !@mandatory? && "close"}
        >
          {render_slot(@inner_block)}

          <button
            :if={!@mandatory?}
            type="button"
            class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            phx-click={assigns."phx-click-close" || "close"}
            phx-target={if assigns."phx-click-close" == nil, do: @myself}
          >
            ✕
          </button>
        </div>
      </dialog>
    </div>
    """
  end

  @impl true
  def handle_event("open", _params, socket) do
    {:noreply, assign(socket, :open?, true)}
  end

  @impl true
  def handle_event("close", _params, %{assigns: %{mandatory?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, :open?, false)}
  end
end
