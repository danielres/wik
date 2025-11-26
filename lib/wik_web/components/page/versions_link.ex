defmodule WikWeb.Components.Page.Versions do
  @moduledoc """
  """

  use WikWeb, :live_component

  attr :ctx, :any, required: true
  attr :page, :any, required: true

  def badge(assigns) do
    ~H"""
    <.link
      patch={~p"/#{@ctx.current_group.slug}/pages/#{@page.slug}/v/#{@page.versions_count}"}
      class="btn btn-sm btn-neutral text-base-content/50"
    >
      v. {@page.versions_count}
    </.link>
    """
  end
end
