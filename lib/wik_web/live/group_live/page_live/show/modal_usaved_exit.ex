defmodule WikWeb.GroupLive.PageLive.Show.ModalUnsavedExit do
  use WikWeb, :html

  def render(assigns) do
    ~H"""
    <.live_component
      module={WikWeb.Components.Generic.Modal}
      id="unsaved-exit-modal"
      open?={@show_unsaved_modal}
      mandatory?={false}
      padding_class="p-4 space-y-4"
      phx-click-close="cancel_exit_modal"
    >
      <div class="space-y-4">
        <div class="text-lg font-semibold">Unsaved changes</div>
        <p class="text-sm opacity-80">
          You have edits that haven&apos;t been saved. What do you want to do?
        </p>

        <div class="flex flex-col gap-2">
          <button
            type="button"
            class="btn btn-sm btn-primary w-full"
            phx-click="save_version_and_continue"
          >
            Save version and continue
          </button>

          <button
            type="button"
            class="btn btn-sm btn-error w-full"
            phx-click="discard_and_continue"
          >
            Forget changes and continue
          </button>
        </div>
      </div>
    </.live_component>
    """
  end
end
