defmodule FrontMatter do
  @moduledoc """
  Handles splitting markdown with front matter into body and metadata,
  and reassembling them back into a single string.
  """

  @front_matter_regex ~r/\A---\n(.*?)\n---\n(.*)\z/s

  def parse(content) when is_list(content) do
    parse(to_string(content))
  end

  def parse(content) when is_binary(content) do
    case Regex.run(@front_matter_regex, content, capture: :all_but_first) do
      [yaml, body] ->
        {:ok, metadata} = YamlElixir.read_from_string(yaml)
        {metadata, body}

      nil ->
        {%{}, content}
    end
  end

  # Reassembles the front matter and body back into a single string.
  def assemble(metadata, body) do
    yaml = metadata_to_yaml(metadata)
    "---\n" <> yaml <> "\n---\n" <> body
  end

  defp metadata_to_yaml(metadata) do
    metadata = sanitize_metadata(metadata)
    Enum.map_join(metadata, "\n", fn {key, value} -> "#{key}: #{value}" end)
  end

  defp sanitize_metadata(metadata) do
    Enum.reduce(metadata, %{}, fn {k, v}, acc ->
      Map.put(acc, k, sanitize_metadata_value(v))
    end)
  end

  defp sanitize_metadata_value(value) when is_binary(value) do
    value
    |> String.replace("\n", " ")
    |> String.replace(": ", " - ")
  end

  defp sanitize_metadata_value(value) do
    value
  end
end
