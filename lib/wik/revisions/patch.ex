defmodule Wik.Revisions.Patch do
  @moduledoc """
  Utilities for working with patches.
  """
  alias Wik.Revisions
  alias Wik.Revisions.Patch
  alias Wik.Page

  def make(original, revised) do
    diff = HSDiff.diff(original, revised)
    HSDiff.optimize(diff)
  end

  def apply(patches, original) do
    case patches do
      [first | _] when is_list(first) ->
        Enum.reduce(patches, original, fn patch, acc ->
          HSDiff.patch(acc, patch)
        end)

      _ ->
        HSDiff.patch(original, patches)
    end
  end

  # TODO: make resource-type agnostic (pass resource_path as argument)
  def take(group_slug, page_slug, index) do
    resource_path = Page.resource_path(group_slug, page_slug)

    cond do
      index <= 0 ->
        {:error, "Index must be greater or smaller than 0"}

      index > 0 ->
        Revisions.take(resource_path, index)
        |> Enum.map(& &1.patch)
        |> Enum.map(&Patch.from_json(&1))
    end
  end

  # def revert(patches, revised) when is_list(patches) do
  #   case patches do
  #     [first | _] when is_list(first) ->
  #       Enum.reduce(patches, {:ok, revised}, fn patch, {:ok, acc} ->
  #         Differ.revert(acc, patch)
  #       end)

  #     _ ->
  #       Differ.revert(revised, patches)
  #   end
  # end

  def to_json(patch) when is_list(patch) do
    patch
    |> Enum.flat_map(fn {k, v} ->
      [convert_key(k), v]
    end)
    |> JSON.encode!()
  end

  def from_json(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, data} when is_list(data) ->
        data
        |> Enum.chunk_every(2)
        |> Enum.map(fn [k, v] ->
          {convert_key(k), v}
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_key("e"), do: :eq
  defp convert_key("d"), do: :del
  defp convert_key("s"), do: :skip
  defp convert_key("i"), do: :ins
  defp convert_key(:eq), do: "e"
  defp convert_key(:del), do: "d"
  defp convert_key(:skip), do: "s"
  defp convert_key(:ins), do: "i"
end
