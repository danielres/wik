defmodule WikWeb.Components.Tag do
  @moduledoc """
  """

  use Phoenix.Component

  attr :tag, :any, required: true
  attr :size, :string, default: "md"
  attr :ctx, :any, default: nil

  def badge(assigns) do
    size_class =
      case assigns.size do
        "xl" -> "badge-xl"
        "md" -> "badge-md"
      end

    assigns = assigns |> assign(:size_class, size_class)

    ~H"""
    <.link
      navigate={if @ctx, do: "/#{@ctx.current_group.slug}/tags/#{@tag.name}", else: nil}
      class={[
        "badge badge-neutral flex gap-0.5 px-[0.5em]",
        !@ctx && "pointer-events-none",
        @ctx && "hover:badge-primary",
        @size_class
      ]}
    >
      <span class="opacity-50">#</span>{"#{@tag.name}"}
    </.link>
    """
  end
end
