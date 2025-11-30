defmodule Utils.Slugify do
  @moduledoc """
  Utility module for generating URL-friendly slugs from text.

  This module provides functionality to:
  - Convert text to lowercase slugs suitable for URLs
  - Ensure slug uniqueness within Ash resources
  - Handle Unicode normalization for international characters
  """

  require Ash.Query

  # ---------- public API ----------

  @doc """
  Generates a URL-friendly slug from the given text.

  Returns an empty string if input is nil.

  ## Examples

      iex> Utils.Slugify.generate("Hello World")
      "hello-world"

      iex> Utils.Slugify.generate("Café Résumé")
      "cafe-resume"

      iex> Utils.Slugify.generate(nil)
      ""
  """
  @spec generate(String.t() | nil) :: String.t()
  def generate(nil), do: ""

  def generate(title) when is_binary(title) do
    title
    |> String.downcase()
    |> normalize_unicode()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/_/u, "-")
    |> String.replace(~r/\s+/u, "-")
    |> String.replace(~r/-+/u, "-")
    |> String.trim("-")
  end

  @doc """
  Sets a unique slug on the changeset if one is not already present.

  If :slug is nil or empty, generates one from :title (or fallback_base)
  and ensures it is unique for the resource backing this changeset.

  ## Parameters
    - changeset: An Ash.Changeset struct
    - fallback_base: Default base string to use if title is not available (default: "")

  ## Returns
    The modified changeset with a unique slug set
  """
  @spec maybe_set_and_ensure_unique_slug(Ash.Changeset.t(), String.t()) :: Ash.Changeset.t()
  def maybe_set_and_ensure_unique_slug(changeset, fallback_base \\ "") do
    resource = changeset.resource

    case Ash.Changeset.get_attribute(changeset, :slug) do
      nil ->
        title = Ash.Changeset.get_attribute(changeset, :title) || fallback_base
        base = generate(title)
        unique = pick_unique_slug(resource, base)
        Ash.Changeset.change_attribute(changeset, :slug, unique)

      "" ->
        base = fallback_base
        unique = pick_unique_slug(resource, base)
        Ash.Changeset.change_attribute(changeset, :slug, unique)

      _slug ->
        changeset
    end
  end

  # ---------- internals ----------

  @spec normalize_unicode(String.t()) :: String.t()
  defp normalize_unicode(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{M}/u, "")
  end

  @spec pick_unique_slug(module(), String.t()) :: String.t()
  defp pick_unique_slug(resource, base), do: pick_unique_slug(resource, base, 0)

  @spec pick_unique_slug(module(), String.t(), non_neg_integer()) :: String.t()
  defp pick_unique_slug(resource, base, tries) do
    candidate =
      case tries do
        0 -> base
        _ -> base <> "-" <> random_suffix(2)
      end

    if slug_exists?(resource, candidate) do
      pick_unique_slug(resource, base, tries + 1)
    else
      candidate
    end
  end

  @spec slug_exists?(module(), String.t()) :: boolean()
  defp slug_exists?(resource, slug) do
    resource
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, []} -> false
      {:ok, _} -> true
      {:error, _} -> true
    end
  end

  @spec random_suffix(pos_integer()) :: String.t()
  defp random_suffix(n) do
    upper = :math.pow(10, n) |> trunc()
    x = :rand.uniform(upper) - 1
    :io_lib.format("~*..0B", [n, x]) |> IO.iodata_to_binary()
  end
end
