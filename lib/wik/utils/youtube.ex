defmodule Wik.Utils.Youtube do
  def is_youtube_url?(url) do
    String.contains?(url, ["youtube.com", "youtu.be"])
  end

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
end
