defmodule WikWeb.SuperAdminLive.Index do
  use WikWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> redirect(to: ~p"/admin/groups")}
  end
end
