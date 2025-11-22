defmodule WikWeb.HelpersTest do
  use ExUnit.Case, async: true

  alias WikWeb.Helpers

  describe "slot_has_content?/1" do
    test "returns false for empty static content" do
      slot = [%{inner_block: %{static: [""]}}]
      refute Helpers.slot_has_content?(slot)
    end

    test "returns true for non-empty static content" do
      slot = [%{inner_block: %{static: ["Hello"]}}]
      assert Helpers.slot_has_content?(slot)
    end

    test "returns true for mixed empty and non-empty content" do
      slot = [
        %{inner_block: %{static: [""]}},
        %{inner_block: %{static: ["Content"]}}
      ]
      assert Helpers.slot_has_content?(slot)
    end

    test "returns false for multiple empty static contents" do
      slot = [
        %{inner_block: %{static: [""]}},
        %{inner_block: %{static: [""]}}
      ]
      refute Helpers.slot_has_content?(slot)
    end

    test "returns true for slot without inner_block structure" do
      slot = [%{some_other_key: "value"}]
      assert Helpers.slot_has_content?(slot)
    end

    test "returns false for empty list" do
      slot = []
      refute Helpers.slot_has_content?(slot)
    end

    test "returns true for multiple non-empty static strings" do
      slot = [%{inner_block: %{static: ["Hello", " World"]}}]
      assert Helpers.slot_has_content?(slot)
    end

    test "returns false when all static strings are empty" do
      slot = [%{inner_block: %{static: ["", "", ""]}}]
      refute Helpers.slot_has_content?(slot)
    end
  end
end
