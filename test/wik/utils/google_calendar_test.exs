defmodule Wik.Utils.GoogleCalendarTest do
  use ExUnit.Case
  doctest Wik.Utils.GoogleCalendar
  alias Wik.Utils.GoogleCalendar

  describe "is_google_calendar_url?" do
    test "returns true for calendar urls" do
      url1 = "https://calendar.google.com/calendar/u/0?cid=CID"
      url2 = "https://google.com"

      assert GoogleCalendar.is_google_calendar_url?(url1) == true
      assert GoogleCalendar.is_google_calendar_url?(url2) == false
    end
  end

  describe "extract_calendar_src" do
    test "returns the src or cid of the calendar" do
      url = "https://calendar.google.com/calendar/u/0?cid=CID"
      assert GoogleCalendar.extract_calendar_src(url) == "CID"
    end
  end

  describe "build calendar embed url" do
    test "supports different modes" do
      calendar_src = "CID"


      opts = [mode: "month"]
      actual = GoogleCalendar.build_calendar_embed_url(calendar_src, opts)
      expected = "https://calendar.google.com/calendar/embed?src=CID&mode=MONTH"
      assert actual == expected

       opts = [mode: "week"]
       actual = GoogleCalendar.build_calendar_embed_url(calendar_src, opts)
       expected = "https://calendar.google.com/calendar/embed?src=CID&mode=WEEK"
       assert actual == expected

       opts = [mode: "agenda"]
       actual = GoogleCalendar.build_calendar_embed_url(calendar_src, opts)
       expected = "https://calendar.google.com/calendar/embed?src=CID&mode=AGENDA"
       assert actual == expected

       opts = [mode: "schedule"]
       actual = GoogleCalendar.build_calendar_embed_url(calendar_src, opts)
       expected = "https://calendar.google.com/calendar/embed?src=CID&mode=AGENDA"
       assert actual == expected
    end

    test "defaults to month if no mode passed" do
      calendar_src = "CID"

      opts = []
      actual = GoogleCalendar.build_calendar_embed_url(calendar_src, opts)
      expected = "https://calendar.google.com/calendar/embed?src=CID&mode=MONTH"
      assert actual == expected
    end
  end
end
