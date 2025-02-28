defmodule Wik.MarkdownTest do
  use ExUnit.Case
  alias Wik.Markdown

  @base_path "/base/path"

  describe "parse/2" do
    test "transforms wiki-style links" do
      markdown = """
      This is a [[Test Page]] link

      ## Meeting notes

      1. [[2025-02-23 - kickoff meeting notes]]
      """

      expected_html =
        """
        <p>
        This is a <a href=\"/base/path/test-page\">Test Page</a> link</p>
        <h2>
        Meeting notes</h2>
        <ol>
          <li>
        <a href=\"/base/path/2025-02-23-kickoff-meeting-notes\">2025-02-23 - kickoff meeting notes</a>  </li>
        </ol>
        """

      assert Markdown.parse(markdown, @base_path) == expected_html
    end

    test "leaves normal links untouched" do
      markdown = "This is a [Test Page](/test-page) link"
      expected_html = ~s(<p>\nThis is a <a href="/test-page">Test Page</a> link</p>\n)
      assert Markdown.parse(markdown, @base_path) == expected_html
    end

    test "leaves pure links untouched" do
      markdown = "This is a pure link: https://example.com"

      expected_html = """
      <p>
      This is a pure link: <a href="https://example.com">https://example.com</a></p>
      """

      assert Markdown.parse(markdown, @base_path) == expected_html
    end

    test "leaves wiki links within code blocks untouched" do
      markdown = """
      ``` markdown
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
