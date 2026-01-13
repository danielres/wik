defmodule WikWeb.GroupLive.PageLive.Show.Panels do
  use WikWeb, :html

  alias WikWeb.GroupLive.PageLive.Panels

  def render(assigns) do
    ~H"""
    <Layouts.panel title="Presences" icon="hero-users">
      <WikWeb.Components.OnlineUsers.list presences={@ctx[:presences]} />
    </Layouts.panel>

    <Layouts.panel :if={not Enum.empty?(@backlinks)} title="Backlinks" icon="hero-link-mini">
      <Panels.Backlinks.panel ctx={@ctx} backlinks={@backlinks} />
    </Layouts.panel>

    <Layouts.panel
      :if={Panels.Tree.tree_visible?(@page_tree_path, @ctx.pages_tree_map)}
      title="Subtree"
      icon="hero-folder-open"
    >
      <Panels.Tree.panel ctx={@ctx} page_tree_path={@page_tree_path} />
    </Layouts.panel>

    <Layouts.panel :if={@toc != []} title="TOC" icon="hero-book-open">
      <Panels.Toc.panel ctx={@ctx} toc={@toc} />
    </Layouts.panel>

    <Layouts.panel>
      <Panels.Versions.panel ctx={@ctx} page_tree_path={@page_tree_path} page={@page} />
    </Layouts.panel>

    <Layouts.panel
      :if={@env == :dev}
      title="Debug"
      icon="hero-bug-ant"
      class="opacity-0 hover:opacity-100"
    >
      <Panels.Debug.panel {assigns} />
    </Layouts.panel>

    {# <:panel :if={true || "@descendants != []"} title="Descendants" icon="hero-folder-open"> }
    {#   <Panels.Panels.panel_descendants }
    {#     ctx={@ctx} }
    {#     page_tree_path={@page_tree_path} }
    {#   /> }
    {# </:panel> }
    """
  end
end
