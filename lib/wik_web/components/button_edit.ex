defmodule WikWeb.Components.ButtonEdit do
  @moduledoc """
  """

  use Phoenix.Component
  use WikWeb, :live_view

  attr :link, :string, required: true
  attr :watch_path, :string, required: true
  attr :open?, :boolean, default: false
  attr :presences, :any, required: true
  attr :class, :string, default: "text-xs"

  def button(assigns) do
    ~H"""
    <div class={[
      "tooltip tooltip-neutral tooltip-bottom",
      @open? && "tooltip-open",
      @class
    ]}>
      <% #
      watch_path_presences =
        @presences |> WikWeb.Presence.users_at_path(@watch_path)

      editors_count =
        watch_path_presences |> length()

      # %>

      <div class="indicator">
        <span
          :if={editors_count > 0}
          class="indicator-item badge badge-neutral border text-base-content/70 rounded-full text-xs p-0 aspect-square"
        >
          {editors_count}
        </span>

        <span class={["cursor-pointer"]}>
          {# <.link }
          {#   class="btn btn-neutral btn-circle hover:btn-primary" }
          {#   patch={@link} }
          {# > }
          {#   <.icon name="hero-pencil-square" /> }
          {# </.link> }

          <.link
            class="btn btn-sm btn-primary text-base-content"
            patch={@link}
          >
            Edit
          </.link>
        </span>
      </div>
    </div>
    """
  end
end
