defmodule WikWeb.GroupLive.PageLive.Show.PageHead do
  use WikWeb, :html

  def render(assigns) do
    ~H"""
    <h1
      class="pagehead-h1 text-3xl mb-8 hover:bg-base-300/20 cursor-pointer"
      phx-click={JS.toggle() |> JS.toggle(to: ".pagehead-form")}
    >
      {@input}
    </h1>
    <div
      style="display:none"
      class="pagehead-form"
    >
      <.form
        :if={Ash.can?({@page, :update}, @current_user)}
        class="grid grid-cols-[1fr_auto] gap-2"
        for={:page_tree_title}
        phx-change="page_title_change"
        phx-submit="page_title_apply"
      >
        <input
          type="text"
          name="title"
          autocomplete="off"
          value={Phoenix.HTML.Form.normalize_value("text", @input)}
          class="text-3xl w-full mb-8 bg-base-300/50 px-1"
        />

        <div class="">
          <button
            type="submit"
            class="btn btn-square hover:btn-accent"
            phx-click={
              JS.toggle(to: ".pagehead-form")
              |> JS.toggle(to: ".pagehead-h1")
            }
          >
            <.icon name="hero-check" />
          </button>
          <button
            type="button"
            class="btn btn-square hover:btn-accent"
            phx-click={
              JS.push("page_title_cancel")
              |> JS.toggle(to: ".pagehead-form")
              |> JS.toggle(to: ".pagehead-h1")
            }
          >
            <.icon name="hero-x-mark" />
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
