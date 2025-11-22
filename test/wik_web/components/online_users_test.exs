defmodule WikWeb.Components.OnlineUsersTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias WikWeb.Components.OnlineUsers

  # Test the component rendering
  describe "list/1" do
    test "renders nothing when presences is nil" do
      assigns = %{presences: nil}
      html = rendered_to_string(~H"<OnlineUsers.list presences={@presences} />")
      refute html =~ "online_users"
    end

    test "renders empty list when presences is empty" do
      assigns = %{presences: []}
      html = rendered_to_string(~H"<OnlineUsers.list presences={@presences} />")
      assert html =~ "online_users"
      assert html =~ "space-y-4"
    end

    test "renders user presence with path" do
      user = %{id: "user-1", email: "test@example.com"}

      assigns = %{
        presences: [
          %{
            id: "user-1",
            user: user,
            metas: [%{path: "/group-1/pages/home"}]
          }
        ]
      }

      html = rendered_to_string(~H"<OnlineUsers.list presences={@presences} />")
      assert html =~ "user-1"
      assert html =~ "pages/home"
    end

    test "renders multiple users" do
      user1 = %{id: "user-1", email: "test1@example.com"}
      user2 = %{id: "user-2", email: "test2@example.com"}

      assigns = %{
        presences: [
          %{
            id: "user-1",
            user: user1,
            metas: [%{path: "/group-1/pages/home"}]
          },
          %{
            id: "user-2",
            user: user2,
            metas: [%{path: "/group-1/pages/about"}]
          }
        ]
      }

      html = rendered_to_string(~H"<OnlineUsers.list presences={@presences} />")
      assert html =~ "user-1"
      assert html =~ "user-2"
    end

    test "renders multiple metas for same user" do
      user = %{id: "user-1", email: "test@example.com"}

      assigns = %{
        presences: [
          %{
            id: "user-1",
            user: user,
            metas: [
              %{path: "/group-1/pages/home"},
              %{path: "/group-1/pages/about"}
            ]
          }
        ]
      }

      html = rendered_to_string(~H"<OnlineUsers.list presences={@presences} />")
      assert html =~ "(2)"
      assert html =~ "pages/home"
      assert html =~ "pages/about"
    end
  end
end
