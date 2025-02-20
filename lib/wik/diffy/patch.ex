defmodule Wik.Diffy.Patch do
  @moduledoc """
  Utilities for working with diffy.
  """
  @doc """
  Serializes a diff (a keyword list of tuples) into a JSON string.
  """
  def to_json(diff) when is_list(diff) do
    data = Enum.map(diff, fn {k, v} -> [Atom.to_string(k), v] end)
    JSON.encode!(data)
  end

  @doc """
  Deserializes a JSON string back into a diff (a list of tuples with atom keys).
  """
  def from_json(json_string) when is_binary(json_string) do
    case JSON.decode(json_string) do
      {:ok, data} ->
        Enum.map(data, fn
          [key, value] -> {String.to_atom(key), value}
          other -> other
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
