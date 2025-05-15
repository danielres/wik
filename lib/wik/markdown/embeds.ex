defmodule Wik.Markdown.Embeds do
  alias Wik.Utils

  def embed_image(meta, raw_opts, src) do
    opts_whitelist = ["width", "height", "border"]
    {alt_text, opts} = parse_embed_alt_data(raw_opts, opts_whitelist)

    style = []
    style = if opts[:width], do: style ++ ["width: #{opts[:width]}px"], else: style
    style = if opts[:height], do: style ++ ["height: #{opts[:height]}px"], else: style
    style = if opts[:border], do: style ++ ["border: #{opts[:border]}px solid"], else: style
    style_str = style |> Enum.join("; ")

    {
      "img",
      [
        {"alt", alt_text},
        {"title", alt_text},
        {"src", src},
        {"style", style_str}
      ],
      nil,
      nil
    }
  end

  def embed_youtube(meta, _raw_opts, src) do
    video_id = Utils.Youtube.extract_youtube_id(src)
    playlist_id = Utils.Youtube.extract_playlist_id(src)
    embed_url = Utils.Youtube.build_embed_url(video_id, playlist_id)

    wrapper_attrs = [
      {"class", "embed-wrapper embed-wrapper-youtube"}
    ]

    type_class = if playlist_id, do: "embed-youtube-playlist", else: "embed-youtube-video"

    iframe_attrs = [
      {"class", "embed embed-youtube #{type_class}"},
      {"src", embed_url},
      {"allowfullscreen", "true"}
    ]

    iframe_node = {"iframe", iframe_attrs, [], meta}

    {:replace, {"div", wrapper_attrs, [iframe_node], meta}}
  end

  def embed_google_calendar(meta, raw_opts, src) do
    calendar_src = Utils.GoogleCalendar.extract_calendar_src(src)
    opts_whitelist = ["mode"]

    {_alt_text, opts} = parse_embed_alt_data(raw_opts, opts_whitelist)
    embed_url = Utils.GoogleCalendar.build_calendar_embed_url(calendar_src, opts)

    wrapper_attrs = [
      {"class", "embed-wrapper embed-wrapper-google-calendar"}
    ]

    iframe_attrs = [
      {"class", "embed embed-google-calendar"},
      {"src", embed_url}
    ]

    iframe_node = {"iframe", iframe_attrs, [], meta}

    {:replace, {"div", wrapper_attrs, [iframe_node], meta}}
  end

  @doc """
  Splits off optional alt-text before the first `|` and returns a tuple
  of `{alt_text, opts}`. Alt defaults to `""` if not provided.
  """
  @spec parse_embed_alt_data(raw :: String.t(), whitelist :: [String.t()]) ::
          {String.t(), keyword()}

  def parse_embed_alt_data(raw, opts_whitelist) do
    cond do
      raw |> String.contains?("|") ->
        list = String.split(raw, "|", trim: true)
        {alt_text, raw_opts} = {Enum.slice(list, 0..-2//1) |> Enum.join("|"), List.last(list)}
        {alt_text, parse_embed_opts(raw_opts, opts_whitelist)}

      raw |> String.contains?("=") ->
        opts = parse_embed_opts(raw, opts_whitelist)
        if opts == [], do: {raw, []}, else: {"", opts}

      true ->
        {raw, []}
    end
  end

  @spec parse_embed_opts(raw :: String.t(), opts_whitelist :: [String.t()]) :: keyword()
  defp parse_embed_opts(raw, opts_whitelist) do
    raw
    |> String.split(",", trim: true)
    |> Enum.flat_map(fn token ->
      case String.split(token, "=", parts: 2) do
        [key, val] ->
          if key in opts_whitelist, do: [{String.to_atom(key), val}], else: []

        _ ->
          []
      end
    end)
  end
end
