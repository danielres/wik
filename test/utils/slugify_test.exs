defmodule Utils.SlugifyTest do
  use ExUnit.Case, async: true

  alias Utils.Slugify

  describe "generate/1" do
    test "returns empty string for nil" do
      assert Slugify.generate(nil) == ""
    end

    test "converts basic text to lowercase slug" do
      assert Slugify.generate("Hello World") == "hello-world"
    end

    test "removes special characters" do
      assert Slugify.generate("Hello, World!") == "hello-world"
      assert Slugify.generate("Test@#$%Page") == "testpage"
    end

    test "replaces multiple spaces with single hyphen" do
      assert Slugify.generate("Hello    World") == "hello-world"
    end

    test "removes consecutive hyphens" do
      assert Slugify.generate("Hello---World") == "hello-world"
    end

    test "trims leading and trailing hyphens" do
      assert Slugify.generate("-Hello World-") == "hello-world"
    end

    test "handles unicode characters" do
      assert Slugify.generate("Café") == "cafe"
      assert Slugify.generate("Résumé") == "resume"
      assert Slugify.generate("Niño") == "nino"
    end

    test "handles mixed unicode and special characters" do
      assert Slugify.generate("Café & Restaurant") == "cafe-restaurant"
    end

    test "handles empty string" do
      assert Slugify.generate("") == ""
    end

    test "handles string with only special characters" do
      assert Slugify.generate("@#$%") == ""
    end

    test "preserves hyphens that are part of the text" do
      assert Slugify.generate("twenty-one pilots") == "twenty-one-pilots"
    end

    test "handles underscores" do
      assert Slugify.generate("hello_world") == "hello_world"
    end
  end
end
