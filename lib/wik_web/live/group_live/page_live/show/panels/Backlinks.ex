defmodule WikWeb.GroupLive.PageLive.Panels.Backlinks do
  use WikWeb, :html

  def panel(assigns) do
    ~H"""
    <ul class="list-disc list-inside">
      <%= if Enum.empty?(@backlinks) do %>
        <li class="text-sm opacity-70">No backlinks yet.</li>
      <% else %>
        <li :for={backlink <- @backlinks} class="text-sm">
          <% source_path = page_tree_path_for(@ctx, backlink.source_page_id) %>
          <.link
            navigate={WikWeb.GroupLive.PageLive.Show.page_url(@ctx.current_group, source_path)}
            class="opacity-70 hover:opacity-100 transition"
          >
            {backlink_label(@ctx, backlink)}
          </.link>
        </li>
      <% end %>
    </ul>
    """
  end

  def page_tree_path_for(ctx, page_id) do
    case Map.get(ctx.pages_tree_by_page_id || %{}, page_id) do
      %{path: path} when is_binary(path) and path != "" -> path
      _ -> nil
    end
  end

  defp backlink_label(ctx, backlink) do
    path = page_tree_path_for(ctx, backlink.source_page_id)

    cond do
      is_binary(path) and path != "" ->
        path

      is_binary(backlink.target_slug) and backlink.target_slug != "" ->
        backlink.target_slug

      true ->
        "Unknown"
    end
  end
end
