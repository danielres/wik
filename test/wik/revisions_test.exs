defmodule Wik.RevisionsTest do
  @moduledoc """
  Test suite for the Wik.Revisions module.
  """

  use Wik.DataCase

  alias Wik.Revisions

  @user_id "1"
  @resource_path "/path/to/resource"
  @doc1 "doc1"
  @doc2 "doc2"
  @doc3 "doc3"
  @doc4 "doc4"
  @doc5 "doc5"

  test "append/4 + count/1" do
    _rev1 = Revisions.append(@user_id, @resource_path, @doc1, @doc2)
    _rev2 = Revisions.append(@user_id, @resource_path, @doc2, @doc3)
    Revisions.append(@user_id, "another/path", @doc1, @doc2)
    assert Revisions.count(@resource_path) == 2
  end

  test "take/2" do
    {:ok, rev1} = Revisions.append(@user_id, @resource_path, @doc1, @doc2)
    {:ok, rev2} = Revisions.append(@user_id, @resource_path, @doc2, @doc3)
    {:ok, rev3} = Revisions.append(@user_id, @resource_path, @doc3, @doc4)
    {:ok, rev4} = Revisions.append(@user_id, @resource_path, @doc4, @doc5)
    take2 = Revisions.take(@resource_path, 2)
    assert take2 == [rev1, rev2]
    take_minus_2 = Revisions.take(@resource_path, -2)
    assert take_minus_2 == [rev4, rev3]
  end
end
