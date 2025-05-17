defmodule Wik.Utils do
  @moduledoc """
  A module for various utility functions.
  """

  @spec slugify(String.t()) :: String.t()
  def slugify(string) do
    string
    |> String.downcase()
    # Decompose combined chars (like accents) into base char + diacritical mark
    |> String.normalize(:nfd)
    # Replace all ampersands with ' and '
    |> String.replace(~r/&/u, " and ")
    # Remove all diacritical marks (combining chars) using Unicode property 'Mark'
    |> String.replace(~r/[\p{M}]/u, "")
    # Replace all non-alphanumeric chars with a hyphen
    |> String.replace(~r/[^a-z0-9]/, "-")
    # Replace consecutive hyphens with a single hyphen
    |> String.replace(~r/-+/, "-")
    # Remove any leading or trailing hyphens
    |> String.replace(~r/^-|-$/, "")
  end

  @spec read_base_path(String.t()) :: {String.t(), String.t()} | {String.t()} | {}
  def read_base_path(""), do: {}

  def read_base_path(base_path) do
    parts =
      base_path
      |> String.split("/")
      |> Enum.filter(&(&1 != ""))

    case parts do
      [group_slug, feature] -> {group_slug, feature}
      [group_slug] -> {group_slug}
      _ -> {}
    end
  end
end
