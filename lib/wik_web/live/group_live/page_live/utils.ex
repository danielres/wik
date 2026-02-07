defmodule WikWeb.GroupLive.PageLive.Utils do
  def encode_path(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map(&URI.encode/1)
    |> Enum.join("/")
  end
end
