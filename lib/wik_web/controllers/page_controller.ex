defmodule WikWeb.PageController do
  use WikWeb, :controller

  alias Wik.{Page, Wiki}

  def home(conn, _params) do
    render(conn, "home.html", layout: false)
  end

  def group_index(conn, %{"group_slug" => group_slug}) do
    redirect(conn, to: ~s"/#{group_slug}/wiki/home")
  end

  def wiki_index(conn, %{"group_slug" => group_slug}) do
    redirect(conn, to: ~s"/#{group_slug}/wiki/home")
  end

  def show(conn, %{"group_slug" => group_slug, "slug" => slug}) do
    user = get_session(conn, :user)
    group_title = user.member_of |> Enum.find(&(&1.slug == group_slug)) |> Map.get(:title)

    case Page.load(group_slug, slug) do
      {:ok, content} ->
        rendered = Wiki.render(group_slug, content)
        backlinks = Page.backlinks(group_slug, slug)

        render(conn, "show.html",
          group_slug: group_slug,
          group_title: group_title,
          slug: slug,
          content: rendered,
          backlinks: backlinks
        )

      :not_found ->
        render(conn, "not_found.html", group_slug: group_slug, slug: slug)
    end
  end

  def edit(conn, %{"group_slug" => group_slug, "slug" => slug}) do
    content =
      case Page.load(group_slug, slug) do
        {:ok, content} -> content
        :not_found -> ""
      end

    render(conn, "edit.html", group_slug: group_slug, slug: slug, content: content)
  end

  def update(conn, %{"group_slug" => group_slug, "slug" => slug, "content" => content}) do
    Page.save(group_slug, slug, content)
    redirect(conn, to: ~p"/#{group_slug}/wiki/#{slug}")
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
