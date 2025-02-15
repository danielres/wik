defmodule WikWeb.PageController do
  use WikWeb, :controller

  def home(conn, _params) do
    render(conn, "home.html", layout: false)
  end

  def group_index(conn, %{"group_slug" => group_slug}) do
    redirect(conn, to: ~p"/#{group_slug}/wiki/home")
  end

  def wiki_index(conn, %{"group_slug" => group_slug}) do
    redirect(conn, to: ~p"/#{group_slug}/wiki/home")
  end
end
