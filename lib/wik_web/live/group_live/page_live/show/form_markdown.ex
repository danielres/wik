defmodule WikWeb.GroupLive.PageLive.Show.FormMarkdown do
  use WikWeb, :html
  alias WikWeb.GroupLive.PageLive.Show

  def render(assigns) do
    ~H"""
    <.live_component
      module={WikWeb.Components.Page.FormMarkdown}
      id={"form-page-#{@page.id}"}
      form_id={"page-form-#{@page.id}"}
      undo_button_id={"editor-undo-#{@page.id}"}
      redo_button_id={"editor-redo-#{@page.id}"}
      exit_after_save?={@exit_after_save?}
      page={@page}
      page_tree_path={@page_tree_path}
      actor={@current_user}
      group={@ctx.current_group}
      editable={@editing?}
      return_to={Show.page_url(@ctx.current_group, @page_tree_path)}
      pages_tree_map={@ctx.pages_tree_map}
    />
    """
  end
end
