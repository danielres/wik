defmodule Wik.Wiki.Page.Utils do
  @moduledoc """
  Page-related helpers (slug canonicalization, etc.).
  """

  @spec canonical_slug(String.t() | nil) :: String.t() | nil
  def canonical_slug(nil), do: nil

  def canonical_slug(slug) when is_binary(slug) do
    slug
    |> String.trim()
    |> String.capitalize()
  end
end
