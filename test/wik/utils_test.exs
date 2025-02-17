defmodule Wik.UtilsTest do
  use ExUnit.Case
  doctest Wik.Utils
  alias Wik.Utils

  describe "slugify/1" do
    test "converts to lowercase and removes accents" do
      assert Utils.slugify("Árvíztűrő tükörfúrógép") == "arvizturo-tukorfurogep"
    end

    test "replaces non-alphanumeric characters with hyphens" do
      assert Utils.slugify("Hello, World!") == "hello-world"
    end

    test "handles multiple consecutive non-alphanumeric characters" do
      assert Utils.slugify("Hello   World!!!") == "hello-world"
    end

    test "removes leading and trailing hyphens" do
      assert Utils.slugify("-Hello-World-") == "hello-world"
    end

    test "handles empty strings" do
      assert Utils.slugify("") == ""
    end

    test "with numbers" do
      assert Utils.slugify("42 is the answer") == "42-is-the-answer"
    end

    test "with ampersand" do
      assert Utils.slugify("&") == "and"
    end

    test "with special characters" do
      assert Utils.slugify("!@#$%^*()_+") == ""
    end

    test "with mixed case, numbers, and special characters" do
      assert Utils.slugify("A1 B2 C3 @#$ D4") == "a1-b2-c3-d4"
    end

    test "with unicode characters" do
      assert Utils.slugify("Café & Croissant") == "cafe-and-croissant"
    end
  end
end
