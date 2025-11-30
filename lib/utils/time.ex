defmodule Utils.Time do
  def relative(date) when is_binary(date) do
    {:ok, datetime} = Timex.parse(date, "{ISO:Extended}")
    Timex.from_now(datetime)
  end

  def relative(date) when is_nil(date) do
    "unknown"
  end

  def relative(%DateTime{} = date) do
    Timex.from_now(date)
    |> String.replace(" seconds", " sec")
    |> String.replace(" second", " sec")
    |> String.replace(" hours", "h")
    |> String.replace(" hour", "h")
    |> String.replace(" minutes", "min")
    |> String.replace(" minute", "min")
  end

  def absolute(date) when is_binary(date) do
    {:ok, datetime} = Timex.parse(date, "{ISO:Extended}")
    absolute(datetime)
  end

  def absolute(date) do
    day = date.day
    ordinal = ordinal_suffix(day)
    month = Timex.format!(date, "{Mshort}")
    year = date.year
    time = Timex.format!(date, "{h24}:{0m}")

    "#{month} #{day}#{ordinal}, #{year} - #{time}"
  end

  defp ordinal_suffix(day) do
    case rem(day, 10) do
      1 when day != 11 -> "st"
      2 when day != 12 -> "nd"
      3 when day != 13 -> "rd"
      _ -> "th"
    end
  end
end
