defmodule Wik.Revisions.Patch do
  @moduledoc """
  Utilities for working with diffy patches.
  """
  def to_json(diff) when is_list(diff) do
    data = Enum.map(diff, fn {k, v} -> [Atom.to_string(k), v] end)
    JSON.encode!(data)
  end

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

  def apply(patches, source) when is_list(patches) do
    Enum.reduce(patches, source, fn patch, acc ->
      apply_single_patch(acc, patch)
    end)
  end

  defp apply_single_patch(source, patch) when is_binary(source) and is_list(patch) do
    flat_patch = List.flatten(patch)
    do_apply_patch(source, flat_patch, 0, "")
  end

  defp do_apply_patch(source, [], pos, acc) do
    acc <> String.slice(source, pos, String.length(source) - pos)
  end

  defp do_apply_patch(source, [{:copy, n} | rest], pos, acc) when is_integer(n) do
    segment = String.slice(source, pos, n)
    do_apply_patch(source, rest, pos + n, acc <> segment)
  end

  defp do_apply_patch(source, [{:skip, n} | rest], pos, acc) when is_integer(n) do
    do_apply_patch(source, rest, pos + n, acc)
  end

  defp do_apply_patch(source, [{:insert, text} | rest], pos, acc) when is_binary(text) do
    do_apply_patch(source, rest, pos, acc <> text)
  end
end
