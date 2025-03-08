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
    patched = Patch.apply(patch, @orignial)
    assert patched == @revised
  end

  test "apply many" do
    patch1 = Patch.make(@orignial, @revised)
    patch2 = Patch.make(@revised, @final)
    patches = [patch1, patch2]
    patched = Patch.apply(patches, @orignial)
    assert patched == @final
  end

  test "to_json/1" do
    patch = Patch.make(@orignial, @revised)
    json = Patch.to_json(patch)

    expected =
      ~s(["d",4,"i",["Hi from **a different** side","* otw","* oo"],"e",1])

    assert json == expected
  end

  test "from_json" do
    patch = Patch.make(@orignial, @revised)
    json = Patch.to_json(patch)
    from_json = Patch.from_json(json)

    assert from_json == patch
  end
end
