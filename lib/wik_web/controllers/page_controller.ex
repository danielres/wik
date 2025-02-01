defmodule WikWeb.PageController do
  use WikWeb, :controller

  alias Wik.{Page, Wiki}

  def show(conn, %{"slug" => slug}) do
    case Page.load(slug) do
      {:ok, content} ->
        rendered = Wiki.render(content)
        render(conn, "show.html", slug: slug, content: rendered)

      :not_found ->
        render(conn, "not_found.html", slug: slug)
    end
  end

  def edit(conn, %{"slug" => slug}) do
    content =
      case Page.load(slug) do
        {:ok, content} -> content
        :not_found -> ""
      end

    render(conn, "edit.html", slug: slug, content: content)
  end

  def update(conn, %{"slug" => slug, "content" => content}) do
    Page.save(slug, content)
    redirect(conn, to: "/pages/#{slug}")
  end
end
