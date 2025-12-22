defmodule WikWeb.Components.Page.Breadcrumbs do
  @moduledoc false

  use WikWeb, :html
  use Phoenix.Component

  attr :page, :any, required: true
  attr :ctx, :any, required: true
  attr :disabled?, :boolean, default: false

  def render(assigns) do
    assigns =
      assigns
      |> assign(:breadcrumbs, build_breadcrumbs(assigns.page, assigns.ctx.pages_map))

    ~H"""
    <div
      id={"page-breadcrumbs-#{@page.id}"}
      class="breadcrumbs text-sm flex items-center gap-2"
    >
      <%= for {crumb, _idx} <- Enum.with_index(@breadcrumbs) do %>
        <%= if crumb.link? do %>
          <.link
            navigate={page_url_from_slug(@ctx.current_group, crumb.slug)}
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

  defp page_url_from_slug(group, slug) do
    "/#{group.slug}/wiki/#{slug}"
  end

  defp build_breadcrumbs(page, pages) do
    slug = page.slug || ""
    segments = slug |> String.split("/", trim: true)

    segments
    |> Enum.drop(-1)
    |> Enum.reduce({[], ""}, fn segment, {acc, prefix} ->
      slug_segment = if prefix == "", do: segment, else: prefix <> "/" <> segment

      page_for_slug =
        case pages do
          list when is_list(list) -> Enum.find(list, &(&1.slug == slug_segment))
          _ -> nil
        end

      label =
        case page_for_slug do
          %{title: title} when is_binary(title) and title != "" -> title
          _ -> humanize_slug_segment(segment)
        end

      crumb = %{slug: slug_segment, label: label, link?: not is_nil(page_for_slug)}
      {[crumb | acc], slug_segment}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp humanize_slug_segment(segment) do
    segment
    |> String.replace("-", " ")
    |> Utils.String.titleize()
  end
end
