defmodule Utils.SlugifyTest do
  use ExUnit.Case, async: true

  alias Utils.Slugify

  describe "generate/1" do
    test "converts basic ASCII text to slug" do
      assert Slugify.generate("Hello World") == "hello-world"
      assert Slugify.generate("The Quick Brown Fox") == "the-quick-brown-fox"
    end

    test "handles multiple spaces" do
      assert Slugify.generate("hello    world") == "hello-world"
      assert Slugify.generate("  leading and trailing  ") == "leading-and-trailing"
    end

    test "removes special characters" do
      assert Slugify.generate("hello!@#$%world") == "helloworld"
      assert Slugify.generate("test & demo") == "test-demo"
      assert Slugify.generate("price: $10.99") == "price-1099"
    end

    test "handles accented characters" do
      assert Slugify.generate("café") == "cafe"
      assert Slugify.generate("naïve") == "naive"
      assert Slugify.generate("Zürich") == "zurich"
      assert Slugify.generate("São Paulo") == "sao-paulo"
    end

    test "handles numbers" do
      assert Slugify.generate("test 123") == "test-123"
      assert Slugify.generate("2024 report") == "2024-report"
      assert Slugify.generate("v1.2.3") == "v123"
    end

    test "handles underscores and hyphens" do
      assert Slugify.generate("hello_world") == "hello-world"
      assert Slugify.generate("already-slugified") == "already-slugified"
      assert Slugify.generate("mixed_dash-example") == "mixed-dash-example"
    end

    test "handles empty strings" do
      assert Slugify.generate("") == ""
      assert Slugify.generate("   ") == ""
    end

    test "handles strings with only special characters" do
      assert Slugify.generate("!!!") == ""
      assert Slugify.generate("@@@###$$$") == ""
    end

    test "collapses multiple hyphens" do
      assert Slugify.generate("hello---world") == "hello-world"
      assert Slugify.generate("test - - demo") == "test-demo"
    end

    test "removes leading and trailing hyphens" do
      assert Slugify.generate("-hello-") == "hello"
      assert Slugify.generate("---test---") == "test"
    end

    test "handles mixed case with numbers and special chars" do
      assert Slugify.generate("Test_123 & Demo!") == "test-123-demo"
      assert Slugify.generate("HTTP/2 Protocol") == "http2-protocol"
    end

    test "handles very long strings" do
      long_text = String.duplicate("word ", 100)
      result = Slugify.generate(long_text)
      assert String.length(result) > 0
      assert result =~ ~r/^word(-word)*$/
    end

    test "preserves lowercase letters" do
      assert Slugify.generate("alreadylowercase") == "alreadylowercase"
    end

    test "handles apostrophes" do
      assert Slugify.generate("it's") == "its"
      assert Slugify.generate("don't") == "dont"
    end

    test "handles parentheses and brackets" do
      assert Slugify.generate("test (demo)") == "test-demo"
      assert Slugify.generate("[important] note") == "important-note"
      assert Slugify.generate("{data}") == "data"
    end

    test "handles slashes" do
      assert Slugify.generate("either/or") == "eitheror"
      assert Slugify.generate("2024/01/01") == "20240101"
    end

    test "idempotent - slugifying a slug returns the same slug" do
      slug = Slugify.generate("hello world")
      assert Slugify.generate(slug) == slug
    end
  end
end

