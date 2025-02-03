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

  def suggestions(conn, %{"term" => term}) do
    pages =
      "pages"
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.map(&Path.rootname/1)
      |> Enum.filter(fn page ->
        String.contains?(String.downcase(page), String.downcase(term))
      end)
      |> Enum.sort()

    json(conn, pages)
  end
end
