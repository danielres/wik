defmodule Utils.Slugify do
  require Ash.Query

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

  defp normalize_unicode(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{M}/u, "")
  end

  def maybe_set_and_ensure_unique_slug(cs, resource_type) do
    case Ash.Changeset.get_attribute(cs, :slug) do
      nil ->
        title = Ash.Changeset.get_attribute(cs, :title) || ""
        base = Utils.Slugify.generate(title)
        unique = pick_unique_slug(base)
        Ash.Changeset.change_attribute(cs, :slug, unique)

      "" ->
        base = resource_type
        unique = pick_unique_slug(base)
        Ash.Changeset.change_attribute(cs, :slug, unique)

      _slug ->
        cs
    end
  end

  defp pick_unique_slug(base), do: pick_unique_slug(base, 0)

  defp pick_unique_slug(base, tries) do
    candidate =
      case tries do
        0 -> base
        _ -> base <> "-" <> random_suffix(4)
      end

    if slug_exists?(candidate) do
      pick_unique_slug(base, tries + 1)
    else
      candidate
    end
  end

  defp slug_exists?(slug) do
    q = __MODULE__ |> Ash.Query.filter(slug == ^slug)

    case Ash.read(q, authorize?: false) do
      {:ok, []} -> false
      {:ok, _} -> true
      {:error, _} -> true
    end
  end

  defp random_suffix(n) do
    # 10^n possibilities; n=4 => 0000..9999 (use 1000..9999 if you don't want leading zeros)
    upper = :math.pow(10, n) |> trunc()
    x = :rand.uniform(upper) - 1
    :io_lib.format("~*..0B", [n, x]) |> IO.iodata_to_binary()
  end
end
