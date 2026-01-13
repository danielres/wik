defmodule WikWeb.GroupLive.PageLive.Show.ActionsBAK do
  use WikWeb, :html

  def render(assigns) do
    ~H"""
    <% btn_class = [
      "flex aspect-square items-center",
      "tooltip tooltip-left",
      "rounded-none",
      "backdrop-blur"
    ] %>
    <menu>
      <ul class={["menu w-full p-0", @editing? and "bg-accent/50 rounded-bl backdrop-blur"]}>
        <%= if Ash.can?({@page, :update}, @current_user)  do %>
          <% editing_btn_class = btn_class ++ ["tooltip-accent"] %>
          <% editing_btn_class_disabled =
            editing_btn_class ++ ["pointer-events-none text-base-content/40"] %>
          <li>
            <%= if @editing? do %>
              <button
                type="button"
                class={
                  if(@editor_state.synced?, do: editing_btn_class, else: editing_btn_class_disabled)
                }
                data-tip="Finish editing"
                phx-click="attempt_end_editing"
                phx-value-synced={@editor_state.synced?}
                phx-value-has_undo={@editor_state.has_undo?}
                phx-value-has_redo={@editor_state.has_redo?}
              >
                <.icon name="hero-x-mark-micro" class="" />
              </button>
            <% else %>
              <button
                type="button"
                class={[btn_class, "text-base-content/50"]}
                phx-click="toggle_editing"
                data-tip="Edit page"
              >
                <.icon name="hero-pencil-solid" />
              </button>
            <% end %>
          </li>
          <%= if @editing? do %>
            <li>
              <button
                form={"page-form-#{@page.id}"}
                type="submit"
                class={
                  if(@editor_state.synced?, do: editing_btn_class_disabled, else: editing_btn_class)
                }
                data-tip={ "Save as v.#{@page.versions_count + 1}" }
              >
                <.icon name="hero-arrow-down-tray-micro" />
              </button>
            </li>
            <li>
              <button
                id={"editor-undo-#{@page.id}"}
                type="button"
                data-tip="Undo"
                class={
                  if(@editor_state.has_undo?, do: editing_btn_class, else: editing_btn_class_disabled)
                }
              >
                <.icon name="hero-arrow-uturn-left-micro" />
              </button>
            </li>
            <li>
              <button
                id={"editor-redo-#{@page.id}"}
                type="button"
                class={
                  if(@editor_state.has_redo?, do: editing_btn_class, else: editing_btn_class_disabled)
                }
                data-tip="Redo"
              >
                <.icon name="hero-arrow-uturn-right-micro" />
              </button>
            </li>
          <% end %>
        <% end %>
      </ul>

      <ul class={["menu w-full p-0"]}>
        <li>
          <button
            type="button"
            phx-click="toggle_source"
            class={[btn_class, if(@source?, do: "bg-base-content/10", else: "text-base-content/50")]}
            data-tip="source markdown"
          >
            <.icon name="hero-hashtag-micro" />
          </button>
        </li>
      </ul>
    </menu>
    """
  end
end
