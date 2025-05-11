defmodule Wik.Utils.Youtube do
  def is_youtube_url?(url) when is_binary(url) do
    String.contains?(url, ["youtube.com", "youtu.be"])
  end

  def is_youtube_url?(_url), do: false

  def extract_youtube_id(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        url
        |> String.split("v=")
        |> Enum.at(1, "")
        |> String.split("&")
        |> List.first("")

      String.contains?(url, "youtu.be/") ->
        url
        |> String.split("youtu.be/")
        |> Enum.at(1, "")
        |> String.split("?")
        |> List.first("")

      true ->
        ""
    end
  end

  def extract_playlist_id(url) do
    cond do
      String.contains?(url, "list=") ->
        url
        |> String.split("list=")
        |> Enum.at(1, "")
        |> String.split("&")
        |> List.first("")

      true ->
        nil
    end
  end

  def build_embed_url(video_id, playlist_id) do
    if playlist_id do
      "https://www.youtube.com/embed/#{video_id}?list=#{playlist_id}&showinfo=1&controls=1&rel=1"
    else
      "https://www.youtube.com/embed/#{video_id}"
    end
  end
end
