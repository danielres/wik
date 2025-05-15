defmodule Wik.Utils.GoogleCalendar do
  @moduledoc """
  Utilities to embed Google Calendar links in Markdown.
  """

  alias URI

  @default_mode "month"
  @base_url "https://calendar.google.com/calendar/embed"

  @type view_mode :: :agenda | :schedule | :week | :month
  @type calendar_opts :: [
          mode: view_mode()
        ]

  @spec is_google_calendar_url?(String.t()) :: boolean()
  def is_google_calendar_url?(url) when is_binary(url) do
    String.contains?(url, "calendar.google.com")
  end

  def is_google_calendar_url?(_), do: false

  @spec extract_calendar_src(String.t()) :: String.t()
  def extract_calendar_src(url) when is_binary(url) do
    uri = URI.parse(url)
    params = URI.decode_query(uri.query || "")
    params["src"] || params["cid"] || ""
  end

  @spec build_calendar_embed_url(String.t(), calendar_opts()) :: String.t()
  def build_calendar_embed_url(src, opts \\ []) do
    mode_str = opts[:mode] |> normalize_mode() |> String.upcase()
    params = [src: src, mode: mode_str]
    query = URI.encode_query(params)
    "#{@base_url}?#{query}"
  end

  defp normalize_mode("schedule"), do: "agenda"
  defp normalize_mode(mode) when mode in ["agenda", "week", "month"], do: mode
  defp normalize_mode(_), do: @default_mode
end
