defmodule WikWeb.Components do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import WikWeb.Gettext

  attr :key, :string
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def shortcut(assigns) do
    ~H"""
    <div
      class={ "relative #{@class}" }
      id={ "shortcut-#{@key}" }
      phx-hook="SetShortcut"
      phx-hook-shortcut-key={@key}
    >
      {render_slot(@inner_block)}
      <span
        id={ "shortcut-hint-#{@key}" }
        class="hint hidden absolute flex items-baseline gap-[0.125em] text-xs -top-2 -left-2  rounded shadow-sm px-[0.5em] leading-none  bg-emerald-200 text-emerald-800 text-nowrap"
      >
        <span>Alt</span>
        <span>+</span>
        <b class="text-sm">{@key}</b>
      </span>
    </div>
    """
  end
end
