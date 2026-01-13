defmodule WikWeb.GroupLive.PageLive.Show.Actions do
  use WikWeb, :html
  alias WikWeb.GroupLive.PageLive.Show.ActionButton

  def render(assigns) do
    ~H"""
    <div class="flex backdrop-blur bg-base-100/40">
      <div class={["contents", @open? && "max-md:hidden"]}>
        <% has_undo_or_redo = @editor_state.has_undo? or @editor_state.has_redo? %>

        <%= if @editing? do %>
          <div class="bg-accent/80 backdrop-blur flex">
            <ActionButton.render
              id={"editor-undo-#{@page.id}"}
              tip="Undo"
              icon="hero-arrow-uturn-left-micro"
              disabled={!@editor_state.has_undo?}
              hidden={!has_undo_or_redo}
            />
            <ActionButton.render
              id={"editor-redo-#{@page.id}"}
              tip="Redo"
              icon="hero-arrow-uturn-right-micro"
              disabled={!@editor_state.has_redo?}
              hidden={!has_undo_or_redo}
            />
            <ActionButton.render
              form={"page-form-#{@page.id}"}
              type="submit"
              tip={ "Save as v.#{@page.versions_count + 1}" }
              icon="hero-arrow-down-tray-micro"
              hidden={@editor_state.synced?}
            />
            <ActionButton.render
              tip="Finish editing"
              icon="hero-x-mark-micro"
              phx-click="attempt_end_editing"
              phx-value-synced={@editor_state.synced?}
              phx-value-has_undo={@editor_state.has_undo?}
              phx-value-has_redo={@editor_state.has_redo?}
              hidden={!@editor_state.synced?}
            />
          </div>
        <% else %>
          <ActionButton.render
            :if={Ash.can?({@page, :update}, @current_user)}
            class={["opacity-50 hover:opacity-100 transition"]}
            phx-click="toggle_editing"
            tip="Edit page"
            icon="hero-pencil-solid"
          />
        <% end %>
      </div>

      <div class={@open? && "max-md:hidden"}>
        <ActionButton.render
          phx-click="toggle_source"
          class={[if(!@source?, do: "opacity-50 hover:opacity-100 transition", else: "bg-primary")]}
          tip={if(@source?, do: "Hide source", else: "Show source")}
          icon="hero-hashtag-micro"
        />
      </div>

      <ActionButton.render
        phx-click="toggle_open?"
        class={[@open? && "hidden", "md:hidden", "opacity-50 hover:opacity-100 transition"]}
        icon="hero-chevron-left-micro"
      />
    </div>
    """
  end
end
