defmodule WikWeb.GroupLive.PageLive.Panels.Toc do
  use WikWeb, :html

  def panel(assigns) do
    ~H"""
    <div
      :for={item <- @toc}
      class="overflow-hidden text-ellipsis text-nowrap text-xs"
      style={ "margin-left: #{( item.level - 1 )/2}rem;" }
    >
      <a class="opacity-70 hover:opacity-100 transition" href={ "##{item.slug}" }>
        {item.title}
      </a>
    </div>
    """
  end
end
