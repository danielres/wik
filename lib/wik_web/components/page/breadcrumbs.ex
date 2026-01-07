defmodule WikWeb.Components.Page.Breadcrumbs do
  @moduledoc false

  use WikWeb, :html
  use Phoenix.Component

  attr :page_id, :string, required: true
  attr :page_tree_path, :string, required: true
  attr :ctx, :any, required: true
  attr :disabled?, :boolean, default: false

  def render(assigns) do
    assigns =
      assigns
      |> assign(:breadcrumbs, build_breadcrumbs(assigns.page_tree_path, assigns.ctx.pages_tree_map))

    ~H"""
    <div
      id={"page-breadcrumbs-#{@page_id}"}
      class="breadcrumbs text-sm flex items-center gap-2"
    >
      <%= for {crumb, _idx} <- Enum.with_index(@breadcrumbs) do %>
        <%= if crumb.link? do %>
          <.link
            navigate={page_url_from_path(@ctx.current_group, crumb.path)}
            class={[
              "font-semibold opacity-30 hover:opacity-100 transition",
              @disabled? and "pointer-events-none"
            ]}
          >
            {crumb.label}
          </.link>
        <% else %>
          <span class="font-semibold opacity-30">{crumb.label}</span>
        <% end %>
        <.icon name="hero-chevron-right-micro" class="opacity-30" />
      <% end %>

      <span class="spacer">&nbsp;</span>
    </div>
    """
  end

  defp page_url_from_path(group, path) do
    WikWeb.GroupLive.PageLive.Show.page_url(group, path)
  end

  defp build_breadcrumbs(path, pages_tree_map) do
    segments = path |> String.split("/", trim: true)

    segments
    |> Enum.drop(-1)
    |> Enum.reduce({[], ""}, fn segment, {acc, prefix} ->
      path_segment = if prefix == "", do: segment, else: prefix <> "/" <> segment

      page_for_path = Map.get(pages_tree_map || %{}, path_segment)

      label = segment

      crumb = %{path: path_segment, label: label, link?: not is_nil(page_for_path)}
      {[crumb | acc], path_segment}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
