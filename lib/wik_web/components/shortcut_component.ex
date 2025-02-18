defmodule WikWeb.Components do
  use Phoenix.Component

  # alias Phoenix.LiveView.JS

  attr :key, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def shortcut(assigns) do
    ~H"""
    <div
      class={ "relative #{@class}" }
      id={ "shortcut-#{@key}" }
      phx-hook="ShortcutComponent"
      phx-hook-shortcut-key={@key}
    >
      {render_slot(@inner_block)}

      <span class="hint
        hidden
        absolute -top-2 -left-2
        flex items-baseline
        px-[0.5em] gap-[0.125em]
        rounded shadow-sm
        text-xs leading-none text-nowrap
        bg-emerald-200 text-emerald-800
      ">
        <span>Alt</span>
        <span>+</span>
        <b class="text-sm">{@key}</b>
      </span>
    </div>
    """
  end
end
