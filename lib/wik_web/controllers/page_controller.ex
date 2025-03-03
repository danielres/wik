defmodule WikWeb.PageController do
  use WikWeb, :controller

  def root_index(conn, _params) do
    conn = conn |> assign(:user, get_session(conn, :user))
    render(conn, "root_index.html")
  end

  def group_index(conn, %{"group_slug" => group_slug}) do
    redirect(conn, to: ~p"/#{group_slug}/wiki/home")
  end

  def wiki_index(conn, %{"group_slug" => group_slug}) do
    redirect(conn, to: ~p"/#{group_slug}/wiki/home")
  end
end
