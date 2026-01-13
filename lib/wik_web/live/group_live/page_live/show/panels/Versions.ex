defmodule WikWeb.GroupLive.PageLive.Panels.Versions do
  use WikWeb, :html

  def panel(assigns) do
    ~H"""
    <.link
      navigate={
        WikWeb.GroupLive.PageLive.History.page_url(
          @ctx.current_group,
          @page_tree_path,
          @page.versions_count
        )
      }
      class="group flex opacity-70 hover:opacity-100 transition items-center gap-2"
    >
      <!-- https://icon-sets.iconify.design/akar-icons/history/ -->
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24">
        <path
          fill="none"
          stroke="currentColor"
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M4.266 16.06a8.92 8.92 0 0 0 3.915 3.978a8.7 8.7 0 0 0 5.471.832a8.8 8.8 0 0 0 4.887-2.64a9.07 9.07 0 0 0 2.388-5.079a9.14 9.14 0 0 0-1.044-5.53a8.9 8.9 0 0 0-4.069-3.815a8.7 8.7 0 0 0-5.5-.608c-1.85.401-3.366 1.313-4.62 2.755c-.151.16-.735.806-1.22 1.781M7.5 8l-3.609.72L3 5m9 4v4l3 2"
        />
      </svg>
      <div class="uppercase tracking-wide text-xs">Version <b>{@page.versions_count}</b></div>
      <.icon name="hero-chevron-right-mini" class="opacity-40 group-hover:opacity-100 ml-auto" />
    </.link>
    """
  end
end
