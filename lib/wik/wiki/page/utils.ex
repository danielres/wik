defmodule Wik.Wiki.Page.Utils do
  

  
  @doc """
Canonicalizes a page slug.

Trims surrounding whitespace and capitalizes the slug string. If `nil` is passed, returns `nil`.

## Parameters

  - slug: The slug to canonicalize; may be `nil`.

## Returns

  - The canonicalized slug string, or `nil` if `slug` was `nil`.
"""
@spec canonical_slug(String.t() | nil) :: String.t() | nil
def canonical_slug(nil), do: nil

  @doc """
  Trims surrounding whitespace and capitalizes the first character of a slug.
  
  The result has leading and trailing whitespace removed and the first character converted to uppercase; other characters are unchanged.
  """
  @spec canonical_slug(String.t() | nil) :: String.t() | nil
  def canonical_slug(slug) when is_binary(slug) do
    slug
    |> String.trim()
    |> String.capitalize()
  end
end