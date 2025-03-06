defmodule Wik.Revisions.PatchTest do
  @moduledoc """
  Test cases for Wik.Revisions.Patch module.
  """

  use ExUnit.Case
  alias Wik.Revisions.Patch

  @orignial """
  Hello from \n the **other** [[side]]
  * one
  * two
  """

  @revised """
  Hi from **a different** side
  * otw
  * oo
  """

  @final """
  Goodbye from the distant **side**
  """

  test "make/2 + apply/2" do
    patch = Patch.make(@orignial, @revised)
    {:ok, patched} = Patch.apply(patch, @orignial)
    assert patched == @revised
  end

  test "apply many" do
    patch1 = Patch.make(@orignial, @revised)
    patch2 = Patch.make(@revised, @final)
    patches = [patch1, patch2]
    {:ok, patched} = Patch.apply(patches, @orignial)
    assert patched == @final
  end

  test "revert/2" do
    patch = Patch.make(@orignial, @revised)
    {:ok, reverted} = Patch.revert(patch, @revised)
    assert reverted == @orignial
  end

  test "revert many" do
    patch1 = Patch.make(@orignial, @revised)
    patch2 = Patch.make(@revised, @final)
    patches = [patch2, patch1]
    {:ok, patched} = Patch.revert(patches, @final)
    assert patched == @orignial
  end

  test "to_json/1" do
    patch = Patch.make(@orignial, @revised)
    json = Patch.to_json(patch)

    expected =
      ~s(["e","H","d","ello","i","i","s",6,"d","\\n the ","s",2,"d","oth","i","a diff","s",2,"i","ent","s",3,"d","[[","s",4,"d","]]","s",4,"d","ne","i","tw","s",3,"d","tw","i","o","s",2])

    assert json == expected
  end

  test "from_json" do
    patch = Patch.make(@orignial, @revised)
    json = Patch.to_json(patch)
    from_json = Patch.from_json(json)

    assert from_json == patch
  end

  test "to_html" do
    expected =
      "H<del>ello</del><ins>i</ins>llo fr<del>\n the </del>om<del>oth</del><ins>a diff</ins> *<ins>ent</ins>her<del>[[</del>** [<del>]]</del>[sid<del>ne</del><ins>tw</ins>]\n*<del>tw</del><ins>o</ins>on"

    patch = Patch.make(@orignial, @revised)
    html = Patch.to_html(patch, @revised)

    assert html == expected
  end
end
