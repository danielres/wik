defmodule Wik.Markdown.EmbedsTest do
  use ExUnit.Case, async: true

  alias Wik.Markdown.Embeds

  describe "parse_embed_alt_data()" do
    test "parses raw alt data into alt_text and opts according to a whitelist" do
      {alt_text, opts} =
        Embeds.parse_embed_alt_data("alt text|height=100,width=200", ["height", "width"])

      assert opts == [height: "100", width: "200"]
      assert alt_text == "alt text"
    end

    test "honors the whitelist" do
      {alt_text, opts} = Embeds.parse_embed_alt_data("alt text|height=100,width=200", ["height"])
      assert opts == [height: "100"]
      assert alt_text == "alt text"
    end

    test "handles case with only alt text" do
      {alt_text, _opts} = Embeds.parse_embed_alt_data("alt text", [])
      assert alt_text == "alt text"
    end

    test "handles case with only alt text containing |" do
      {alt_text, _opts} = Embeds.parse_embed_alt_data("alt | text|width=200", [])
      assert alt_text == "alt | text"
    end

    test "handles case with only opts" do
      {alt_text, opts} = Embeds.parse_embed_alt_data("width=100,height=200", ["width", "height"])
      assert alt_text == ""
      assert opts == [width: "100", height: "200"]
    end

    test "handles case with alt_text containing =" do
      {alt_text, opts} =
        Embeds.parse_embed_alt_data("picture=parrot|width=100,height=200", ["width", "height"])

      assert alt_text == "picture=parrot"
      assert opts == [width: "100", height: "200"]
    end

    test "handles case with only alt_text, containing =" do
      {alt_text, opts} =
        Embeds.parse_embed_alt_data("picture=parrot", [])

      assert alt_text == "picture=parrot"
      assert opts == []
    end
  end
end
