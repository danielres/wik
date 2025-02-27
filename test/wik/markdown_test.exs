defmodule Wik.MarkdownTest do
  use ExUnit.Case
  alias Wik.Markdown

  @base_path "/base/path"

  describe "parse/2" do
    test "transforms wiki-style links" do
      markdown = "This is a [[Test Page]] link"

      expected_html =
        ~s(<p>\nThis is a <a href=\"/base/path/test-page\">Test Page</a> link</p>\n)

      assert Markdown.parse(markdown, @base_path) == expected_html
    end

    test "leaves normal links untouched" do
      markdown = "This is a [Test Page](/test-page) link"
      expected_html = ~s(<p>\nThis is a <a href="/test-page">Test Page</a> link</p>\n)
      assert Markdown.parse(markdown, @base_path) == expected_html
    end

    test "leaves pure links untouched" do
      markdown = "This is a pure link: https://example.com"

      expected_html =
        ~s(<p>\nThis is a pure link: <a href="https://example.com">https://example.com</a></p>\n)

      assert Markdown.parse(markdown, @base_path) == expected_html
    end

    test "leaves wiki links within code blocks untouched" do
      markdown = """
      ```markdown
      A wiki link: [[Hello world]]
      ```
      """

      expected_html = """
      <pre><code class="markdown">A wiki link: [[Hello world]]</code></pre>
      """

      assert Markdown.parse(markdown, @base_path) == expected_html
    end
  end
end
