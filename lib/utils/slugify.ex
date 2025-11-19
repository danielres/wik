defmodule Utils.Slugify do
  require Ash.Query

  # ---------- public API ----------

  def generate(nil), do: ""

  def generate(title) do
    title
    |> String.downcase()
    |> normalize_unicode()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/\s+/u, "-")
    |> String.replace(~r/-+/u, "-")
    |> String.trim("-")
  end

  @doc """
  If :slug is nil or empty, generate one from :title (or fallback_base)
  and ensure it is unique for the resource backing this changeset.
  """
  def maybe_set_and_ensure_unique_slug(changeset, fallback_base) do
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

  defp normalize_unicode(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{M}/u, "")
  end

  defp pick_unique_slug(resource, base), do: pick_unique_slug(resource, base, 0)

  defp pick_unique_slug(resource, base, tries) do
    candidate =
      case tries do
        0 -> base
        _ -> base <> "-" <> random_suffix(4)
      end

    if slug_exists?(resource, candidate) do
      pick_unique_slug(resource, base, tries + 1)
    else
      candidate
    end
  end

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

  defp random_suffix(n) do
    upper = :math.pow(10, n) |> trunc()
    x = :rand.uniform(upper) - 1
    :io_lib.format("~*..0B", [n, x]) |> IO.iodata_to_binary()
  end
end
