defmodule Utils.TimeTest do
  use ExUnit.Case, async: true

  alias Utils.Time, as: TimeUtils

  describe "relative/1" do
    test "formats current time as 'now'" do
      now = DateTime.utc_now()
      assert TimeUtils.relative(now) == "now"
    end

    test "formats time 30 seconds ago" do
      time = DateTime.utc_now() |> DateTime.add(-30, :second)
      assert TimeUtils.relative(time) == "30 sec ago"
    end

    test "formats time 1min ago" do
      time = DateTime.utc_now() |> DateTime.add(-60, :second)
      assert TimeUtils.relative(time) == "1min ago"
    end

    test "formats time 5min ago" do
      time = DateTime.utc_now() |> DateTime.add(-5 * 60, :second)
      assert TimeUtils.relative(time) == "5min ago"
    end

    test "formats time 59min ago" do
      time = DateTime.utc_now() |> DateTime.add(-59 * 60, :second)
      assert TimeUtils.relative(time) == "59min ago"
    end

    test "formats time 1h ago" do
      time = DateTime.utc_now() |> DateTime.add(-60 * 60, :second)
      assert TimeUtils.relative(time) == "1h ago"
    end

    test "formats time 3h ago" do
      time = DateTime.utc_now() |> DateTime.add(-3 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "3h ago"
    end

    test "formats time 23h ago" do
      time = DateTime.utc_now() |> DateTime.add(-23 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "23h ago"
    end

    test "formats time yesterday" do
      time = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "yesterday"
    end

    test "formats time 5 days ago" do
      time = DateTime.utc_now() |> DateTime.add(-5 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "5 days ago"
    end

    test "formats time 29 days ago" do
      time = DateTime.utc_now() |> DateTime.add(-29 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "29 days ago"
    end

    test "formats time 1 month ago" do
      time = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "1 month ago"
    end

    test "formats time 3 months ago" do
      time = DateTime.utc_now() |> DateTime.add(-90 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "3 months ago"
    end

    test "formats time 11 months ago" do
      time = DateTime.utc_now() |> DateTime.add(-330 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "11 months ago"
    end

    test "formats time 1 year ago" do
      time = DateTime.utc_now() |> DateTime.add(-365 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "1 year ago"
    end

    test "formats time 2 years ago" do
      time = DateTime.utc_now() |> DateTime.add(-2 * 365 * 24 * 60 * 60, :second)
      assert TimeUtils.relative(time) == "2 years ago"
    end

    test "handles future times" do
      future_time = DateTime.utc_now() |> DateTime.add(60, :second)
      assert TimeUtils.relative(future_time) == "in 1min"
    end

    test "handles nil gracefully" do
      assert TimeUtils.relative(nil) == "unknown"
    end
  end
end
