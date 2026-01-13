defmodule WikWeb.GroupLive.PageLive.Show.ActionButton do
  use WikWeb, :html

  attr :class, :any, default: ""
  attr :tip, :string, required: false, default: nil
  attr :icon, :string, required: true
  attr :form, :string, required: false, default: nil
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :hidden, :boolean, default: false
  attr :id, :string, default: nil
  attr :variant, :atom, values: [:neutral, :accent, :primary], default: :neutral
  attr :rest, :global

  def render(assigns) do
    ~H"""
    <button
      id={@id}
      form={@form}
      type={@type}
      class={[
        "aspect-square w-10",
        if(@disabled, do: "opacity-20", else: "cursor-pointer"),
        if(@hidden, do: "hidden"),
        @tip && "tooltip",
        @class
      ]}
      data-tip={@tip}
      {@rest}
    >
      <.icon name={@icon} class="size-4" />
    </button>
    """
  end
end
