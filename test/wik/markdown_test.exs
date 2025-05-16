defmodule Wik.MarkdownTest do
  use ExUnit.Case
  alias Wik.Markdown

  @base_path "/base/path"
  describe "sanitize/1" do
    test "strips script tags" do
      markdown = """
      <script>alert('hello')</script>
      """

      sanitized = """
      alert('hello')
      """

      assert markdown |> Markdown.sanitize() == sanitized
    end

    test "preserves select html entities as is" do
      markdown = """
      <script>alert("hello")</script>
      < **bold** > coffee & croissants 
      """

      sanitized = """
      alert("hello")
      < **bold** > coffee & croissants 
      """

      assert markdown |> Markdown.sanitize() == sanitized
    end
  end

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

      assert Markdown.to_html(markdown, @base_path) == expected_html
    end

    test "leaves normal links untouched" do
      markdown = "This is a [Test Page](/test-page) link"
      expected_html = ~s(<p>\nThis is a <a href="/test-page">Test Page</a> link</p>\n)
      assert Markdown.to_html(markdown, @base_path) == expected_html
    end

    test "leaves pure links untouched" do
      markdown = "This is a pure link: https://example.com"

      expected_html = """
      <p>
      This is a pure link: <a href="https://example.com">https://example.com</a></p>
      """

      assert Markdown.to_html(markdown, @base_path) == expected_html
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

      assert Markdown.to_html(markdown, @base_path) == expected_html
    end
  end

  describe "Custom embeds" do
    test "Google Calendar embed - mode=month" do
      markdown = """
      ![mode=month](https://calendar.google.com/calendar/u/0?cid=CID)
      """

      expected_html = """
      <p>
        <div class="embed-wrapper embed-wrapper-google-calendar">
          <iframe class="embed embed-google-calendar" src="https://calendar.google.com/calendar/embed?src=CID&mode=MONTH">
          </iframe>
        </div>
      </p>
      """

      assert Markdown.to_html(markdown, @base_path) == expected_html
    end

    test "Google Calendar embed - mode=schedule" do
      markdown = """
      ![mode=schedule](https://calendar.google.com/calendar/u/0?cid=CID)
      """

      expected_html = """
      <p>
        <div class="embed-wrapper embed-wrapper-google-calendar">
          <iframe class="embed embed-google-calendar" src="https://calendar.google.com/calendar/embed?src=CID&mode=AGENDA">
          </iframe>
        </div>
      </p>
      """

      assert Markdown.to_html(markdown, @base_path) == expected_html
    end

    test "Youtube video embed" do
      markdown = """
      ![](https://youtu.be/VIDEO_ID)
      """

      expected_html = """
      <p>
        <div class="embed-wrapper embed-wrapper-youtube">
          <iframe class="embed embed-youtube embed-youtube-video" src="https://www.youtube.com/embed/VIDEO_ID" allowfullscreen="true">
          </iframe>
        </div>
      </p>
      """

      assert Markdown.to_html(markdown, @base_path) == expected_html
    end

    test "Youtube playlist embed" do
      markdown = """
      ![](https://youtube.com/playlist?list=LIST_ID)
      """

      expected_html = """
      <p>
        <div class="embed-wrapper embed-wrapper-youtube">
          <iframe class="embed embed-youtube embed-youtube-playlist" src="https://www.youtube.com/embed/?list=LIST_ID&showinfo=1&controls=1&rel=1" allowfullscreen="true">
          </iframe>
        </div>
      </p>
      """

      assert Markdown.to_html(markdown, @base_path) == expected_html
    end
  end
end
