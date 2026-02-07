defmodule WikWeb.AuthController.Dev do
  use WikWeb, :controller
  require Ash.Query
  require Logger
  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers

  def login(conn, _params) do
    return_to = "/"

    id = System.get_env("DEV_USER_ID", "000000000")

    img =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAcBAMAAACAI8KnAAABg2lDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw0AcxV9TpSKVDlYQcQhSneyioo61CkWoEGqFVh1Mrp/QpCFJcXEUXAsOfixWHVycdXVwFQTBDxB3wUnRRUr8X1JoEePBcT/e3XvcvQOERoWpZlcMUDXLSCXiYia7KgZeISCEAYxgRmamPidJSXiOr3v4+HoX5Vne5/4cfbm8yQCfSBxjumERbxBPb1o6533iMCvJOeJz4nGDLkj8yHXF5TfORYcFnhk20ql54jCxWOxgpYNZyVCJp4gjOVWjfCHjco7zFme1UmOte/IXBvPayjLXaQ4jgUUsQYIIBTWUUYGFKK0aKSZStB/38A85folcCrnKYORYQBUqZMcP/ge/uzULkxNuUjAOdL/Y9scoENgFmnXb/j627eYJ4H8GrrS2v9oAZj9Jr7e1yBEQ2gYurtuasgdc7gCDT7psyI7kpykUCsD7GX1TFui/BXrX3N5a+zh9ANLUVfIGODgExoqUve7x7p7O3v490+rvB903ctGnToVWAAAAIVBMVEVKHBxKHD5vKl68TqDKcrS8oE5OvLyFvE6eynK62Zv36fNZSEXTAAAAAWJLR0QAiAUdSAAAAAlwSFlzAAAuIwAALiMBeKU/dgAAAAd0SU1FB+kCDxUqHL67UiAAAAAZdEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBXgQ4XAAAAZklEQVQY02OYiQDT0mYy4OROSw1NQ+e6IIBbmgsBrrGxCULAGJ3LYGzitWoVkOm1aolLBzbuQkEg11GKMLcDL7cc2d5yIrjOxiBg4l6OyS0vBjKVjJWUjc2xcSECxiAeMVwEQOMCAM+GiLYSTcf8AAAAAElFTkSuQmCC"

    attrs = %{
      tg_id: id,
      tg_first_name: "Testuser",
      tg_last_name: "Testuser",
      tg_username: "Testuser",
      tg_photo_url: img
    }

    db_user =
      Wik.Accounts.User
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(upsert?: true, upsert_identity: :unique_tg_id)

    {:ok, token, _claims} = Jwt.token_for_user(db_user)
    db_user = Ash.Resource.set_metadata(db_user, %{token: token})

    conn
    |> AuthHelpers.store_in_session(db_user)
    |> redirect(to: return_to)
  end
end
