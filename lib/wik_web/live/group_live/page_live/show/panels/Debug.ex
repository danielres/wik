defmodule WikWeb.GroupLive.PageLive.Panels.Debug do
  use WikWeb, :html

  def panel(assigns) do
    ~H"""
    <div class="font-mono text-xs opacity-70">
      <dd>page path: {@page_tree_path}</dd>
      <div>editing?: {@editing?}</div>
      <div>synced?: {@editor_state.synced?}</div>
      <div>has_undo?: {@editor_state.has_undo?}</div>
      <div>has_redo?: {@editor_state.has_redo?}</div>
      <div>exit_after_save?: {@exit_after_save?}</div>
      <div>show_unsaved_modal?: {@show_unsaved_modal}</div>
    </div>
    """
  end
end
