defmodule WikWeb.Page.Revisions.ShowLiveTest do
  @moduledoc """
  Test suite for the WikWeb.Page.Revisions.ShowLive module.
  """

  use WikWeb.ConnCase, async: true
  use ExUnit.Case
  import Phoenix.LiveViewTest
  import WikWeb.TestHelpers
  import Wik.GroupsFixtures
  import Wik.UsersFixtures
  alias WikWeb.Page.Revisions.ShowLive
  alias Wik.Page
  alias Wik.Revisions

  @page_slug "page_slug"
  @txt_v1 "v1"
  @txt_v2 "v2"
  @txt_v3 "v3"

  # setup_all do
  #   :ok
  # end

  setup %{conn: conn} do
    Ecto.Adapters.SQL.Sandbox.checkout(Wik.Repo)

    group = group_fixture()
    fake_user = fake_user_fixture(%{member_of: [group]})
    conn = conn |> Plug.Test.init_test_session(user: fake_user)

    file_path = Page.file_path(group.slug, @page_slug)
    File.rm(file_path)

    Page.upsert(fake_user.id, group.slug, @page_slug, @txt_v1)
    Page.upsert(fake_user.id, group.slug, @page_slug, @txt_v2)
    Page.upsert(fake_user.id, group.slug, @page_slug, @txt_v3)

    resource_path = Page.resource_path(group.slug, @page_slug)

    {:ok, conn: conn, group: group, resource_path: resource_path}
  end

  # test "foo", %{conn: conn, group: group} do
  #   route_edit = Wiki.Page.EditLive.make_route(group.slug, @page_slug)
  #   {:ok, view, _html} = conn |> live(route_edit)
  #   assert view |> element(tid(["field-edit"])) |> render() =~ @v3
  # end

  test "Page.Revisions.ShowLive: browsing a page revisions history", %{
    conn: conn,
    group: group,
    resource_path: resource_path
  } do
    actual_count = Revisions.count(resource_path)
    route_show = ShowLive.make_route(group.slug, @page_slug, actual_count)

    {:ok, view, _html} = conn |> live(route_show)

    # Check that we have the correct number of revisions
    count = 3
    assert actual_count == count

    # Check that the counter is correct
    assert view |> element(tid(["revisions-counter", "index"])) |> render() =~ "3"
    assert view |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"

    # Check that the content is correct
    assert view |> element(tid(["revisions-original"])) |> render() =~ @txt_v2
    assert view |> element(tid(["revisions-revised"])) |> render() =~ @txt_v3

    # Check that the next button is disabled
    assert view |> element(tid(["action-next"])) |> render() =~ "disabled"

    # Check that everything is correct after clicking on "Prev"
    view |> element(tid(["action-prev"])) |> render_click()
    assert view |> element(tid(["revisions-counter", "index"])) |> render() =~ "2"
    assert view |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"
    assert view |> element(tid(["revisions-original"])) |> render() =~ @txt_v1
    assert view |> element(tid(["revisions-revised"])) |> render() =~ @txt_v2

    # Check that everything is correct after clicking on "Prev" again
    view |> element(tid(["action-prev"])) |> render_click()
    assert view |> element(tid(["revisions-counter", "index"])) |> render() =~ "1"
    assert view |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"
    assert view |> element(tid(["revisions-original"])) |> render() =~ ""
    assert view |> element(tid(["revisions-revised"])) |> render() =~ @txt_v1

    # We're at the first revision, check that the prev button is disabled
    assert view |> element(tid(["action-prev"])) |> render() =~ "disabled"

    # Check that everything is correct after clicking on "Next"
    view |> element(tid(["action-next"])) |> render_click()
    assert view |> element(tid(["revisions-counter", "index"])) |> render() =~ "2"
    assert view |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"
    assert view |> element(tid(["revisions-original"])) |> render() =~ @txt_v1
    assert view |> element(tid(["revisions-revised"])) |> render() =~ @txt_v2

    # Check that everything is correct after clicking on "Next" again
    view |> element(tid(["action-next"])) |> render_click()
    assert view |> element(tid(["revisions-counter", "index"])) |> render() =~ "3"
    assert view |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"
    assert view |> element(tid(["revisions-original"])) |> render() =~ @txt_v2
    assert view |> element(tid(["revisions-revised"])) |> render() =~ @txt_v3

    # We're at the last revision, check that the next button is disabled
    assert view |> element(tid(["action-next"])) |> render() =~ "disabled"

    # Check that direct url access works properly
    route_show_1 = ShowLive.make_route(group.slug, @page_slug, 1)
    {:ok, view_1, _html} = conn |> live(route_show_1)
    assert view_1 |> element(tid(["revisions-counter", "index"])) |> render() =~ "1"
    assert view_1 |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"
    assert view_1 |> element(tid(["revisions-original"])) |> render() =~ ""
    assert view_1 |> element(tid(["revisions-revised"])) |> render() =~ @txt_v1

    route_show_2 = ShowLive.make_route(group.slug, @page_slug, 2)
    {:ok, view_2, _html} = conn |> live(route_show_2)
    assert view_2 |> element(tid(["revisions-counter", "index"])) |> render() =~ "2"
    assert view_2 |> element(tid(["revisions-counter", "total"])) |> render() =~ "#{count}"
    assert view_2 |> element(tid(["revisions-original"])) |> render() =~ ""
    assert view_2 |> element(tid(["revisions-revised"])) |> render() =~ @txt_v2
  end
end
