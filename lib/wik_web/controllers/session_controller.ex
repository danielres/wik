defmodule WikWeb.SessionController do
  use WikWeb, :controller

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def dev_login(conn, params) do
    username = params["user"]

    all_groups = Wik.Groups.list_groups()

    serialized =
      all_groups
      |> Enum.map(fn group ->
        %{
          id: group.id,
          name: group.name,
          slug: group.slug
        }
      end)

    img =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAcBAMAAACAI8KnAAABg2lDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw0AcxV9TpSKVDlYQcQhSneyioo61CkWoEGqFVh1Mrp/QpCFJcXEUXAsOfixWHVycdXVwFQTBDxB3wUnRRUr8X1JoEePBcT/e3XvcvQOERoWpZlcMUDXLSCXiYia7KgZeISCEAYxgRmamPidJSXiOr3v4+HoX5Vne5/4cfbm8yQCfSBxjumERbxBPb1o6533iMCvJOeJz4nGDLkj8yHXF5TfORYcFnhk20ql54jCxWOxgpYNZyVCJp4gjOVWjfCHjco7zFme1UmOte/IXBvPayjLXaQ4jgUUsQYIIBTWUUYGFKK0aKSZStB/38A85folcCrnKYORYQBUqZMcP/ge/uzULkxNuUjAOdL/Y9scoENgFmnXb/j627eYJ4H8GrrS2v9oAZj9Jr7e1yBEQ2gYurtuasgdc7gCDT7psyI7kpykUCsD7GX1TFui/BXrX3N5a+zh9ANLUVfIGODgExoqUve7x7p7O3v490+rvB903ctGnToVWAAAAIVBMVEVKHBxKHD5vKl68TqDKcrS8oE5OvLyFvE6eynK62Zv36fNZSEXTAAAAAWJLR0QAiAUdSAAAAAlwSFlzAAAuIwAALiMBeKU/dgAAAAd0SU1FB+kCDxUqHL67UiAAAAAZdEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBXgQ4XAAAAZklEQVQY02OYiQDT0mYy4OROSw1NQ+e6IIBbmgsBrrGxCULAGJ3LYGzitWoVkOm1aolLBzbuQkEg11GKMLcDL7cc2d5yIrjOxiBg4l6OyS0vBjKVjJWUjc2xcSECxiAeMVwEQOMCAM+GiLYSTcf8AAAAAElFTkSuQmCC"

    user = %{
      id: username,
      first_name: "Dev",
      last_name: "User",
      auth_date: "2023-01-01",
      username: username,
      photo_url: img,
      member_of: serialized
    }

    Wik.Users.persist_session_user(user)

    conn
    |> put_session(:user, user)
    |> configure_session(renew: true)
    |> redirect(to: get_session(conn, :redirect_after_login) || "/")
  end
end
