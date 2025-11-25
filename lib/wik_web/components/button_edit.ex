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

      locked? = watch_path_presences |> length() > 0
      # %>

      <span class={["cursor-pointer"]}>
        <%= if locked? do %>
          <span class="btn btn-neutral btn-circle cursor-progress">
            <.icon name="hero-lock-closed" />
          </span>
        <% else %>
          <.link
            class="btn btn-neutral btn-circle hover:btn-primary"
            patch={@link}
          >
            <.icon name="hero-pencil-square" />
          </.link>
        <% end %>
      </span>
      <%= if locked? do %>
        <div class="tooltip-content" style="font-size: inherit">
          Currently edited by <br /> {watch_path_presences |> List.first()}
        </div>
      <% else %>
        <div class="tooltip-content" style="font-size: inherit">
          Edit group
        </div>
      <% end %>
    </div>
    """
  end
end
