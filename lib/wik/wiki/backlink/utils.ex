defmodule Wik.Wiki.Backlink.Utils do
  @moduledoc """
  Backlink management helpers for wiki pages.
  """

  require Ash.Query
  alias Wik.Wiki.Backlink
  alias Wik.Wiki.Page

  @doc """
  Parse markdown for backlink target slugs.

  Supports `[[wikilink]]` and relative markdown links like `[text](/group-slug/wiki/slug)`.
  Only returns slugs scoped to the given group_slug. Deduplicates results.
  """
  @spec parse_slugs(String.t() | nil, String.t()) :: MapSet.t(String.t())
  def parse_slugs(markdown, group_slug) when is_binary(group_slug) do
    markdown = markdown || ""

    wikilinks =
      Regex.scan(~r/\[\[([^\[\]]+)\]\]/, markdown, capture: :all_but_first)
      |> Enum.map(&hd/1)

    relative_links =
      Regex.scan(~r/\[[^\]]*\]\((\/[^\s\)]+)\)/, markdown, capture: :all_but_first)
      |> Enum.map(&hd/1)
      |> Enum.flat_map(&extract_slug_from_path(&1, group_slug))

    (wikilinks ++ relative_links)
    |> Enum.map(&normalize_slug/1)
    |> Enum.map(&Utils.Slugify.generate/1)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp extract_slug_from_path(path, group_slug) do
    # Only accept relative links within the same group, in the form /<group_slug>/wiki/<slug>
    cond do
      String.contains?(path, "..") ->
        []

      String.starts_with?(path, "/#{group_slug}/wiki/") ->
        [path |> String.trim_trailing("/") |> String.split("/", parts: 4) |> List.last()]

      true ->
        []
    end
  end

  defp normalize_slug(slug) do
    slug
    |> URI.decode()
    |> String.trim()
    |> case do
      "" -> nil
      value -> value
    end
  rescue
    _ -> nil
  end

  @doc """
  Rebuild backlinks for a page when its text changes. Runs inside the page action transaction.
  """
  @spec rebuild_for_page(Page.t(), Ash.Changeset.t()) :: :ok | {:error, term()}
  def rebuild_for_page(%Page{} = page, _changeset) do
    with {:ok, group_slug} <- fetch_group_slug(page),
         slugs <- parse_slugs(page.text, group_slug) do
      do_rebuild(page, slugs)
    end
  end

  defp do_rebuild(page, slugs) do
    {:ok, existing} =
      Backlink
      |> Ash.Query.filter(source_page_id == ^page.id and group_id == ^page.group_id)
      |> Ash.read(authorize?: false)

    existing_slugs = MapSet.new(existing, & &1.target_slug)
    to_delete = Enum.filter(existing, fn bl -> bl.target_slug not in slugs end)
    to_create = MapSet.difference(slugs, existing_slugs)

    Enum.each(to_delete, fn backlink -> Ash.destroy!(backlink, authorize?: false) end)

    target_pages =
      if MapSet.size(to_create) > 0 do
        Page
        |> Ash.Query.filter(group_id == ^page.group_id and slug in ^MapSet.to_list(to_create))
        |> Ash.read!(authorize?: false)
        |> Map.new(fn p -> {p.slug, p} end)
      else
        %{}
      end

    Enum.each(to_create, fn slug ->
      target_page_id = target_pages[slug] && target_pages[slug].id

      Backlink
      |> Ash.Changeset.for_create(
        :create,
        %{
          group_id: page.group_id,
          source_page_id: page.id,
          target_slug: slug,
          target_page_id: target_page_id
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
    end)

    broadcast_updates(page.group_id, slugs, Map.values(target_pages))
    :ok
  end

  @doc """
  When a new page is created, reconcile any backlinks that pointed at its slug.
  """
  @spec reconcile_new_target(Page.t()) :: :ok
  def reconcile_new_target(%Page{} = page) do
    {:ok, backlinks} =
      Backlink
      |> Ash.Query.filter(
        group_id == ^page.group_id and target_slug == ^page.slug and is_nil(target_page_id)
      )
      |> Ash.read(authorize?: false)

    Enum.each(backlinks, fn backlink ->
      backlink
      |> Ash.Changeset.for_update(:update, %{target_page_id: page.id}, authorize?: false)
      |> Ash.update!(authorize?: false)
    end)

    if backlinks != [] do
      broadcast_updates(page.group_id, [page.slug], [page])
    end

    :ok
  end

  @doc """
  List backlinks pointing to a page (by id or slug), scoped to group.
  """
  @spec list_for_page(Page.t()) :: [Backlink.t()]
  def list_for_page(%Page{} = page) do
    page_slug = Utils.Slugify.generate(page.slug)

    Backlink
    |> Ash.Query.filter(
      group_id == ^page.group_id and
        (target_page_id == ^page.id or target_slug == ^page_slug)
    )
    |> Ash.Query.load([:source_page])
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Delete backlinks where the page is source or target.
  """
  @spec delete_for_page(Page.t()) :: :ok
  def delete_for_page(%Page{} = page) do
    {:ok, backlinks} =
      Backlink
      |> Ash.Query.filter(
        group_id == ^page.group_id and (source_page_id == ^page.id or target_page_id == ^page.id)
      )
      |> Ash.read(authorize?: false)

    Enum.each(backlinks, fn backlink -> Ash.destroy!(backlink, authorize?: false) end)
    :ok
  end

  defp fetch_group_slug(%Page{group: %{slug: slug}}) when is_binary(slug), do: {:ok, slug}

  defp fetch_group_slug(%Page{group_id: group_id}) do
    group = Wik.Accounts.Group |> Ash.get!(group_id, authorize?: false)
    {:ok, group.slug}
  rescue
    _ -> {:error, :group_not_found}
  end

  defp broadcast_updates(group_id, slugs, target_pages) do
    Enum.each(slugs, fn slug ->
      Phoenix.PubSub.broadcast(
        Wik.PubSub,
        "backlinks:slug:#{group_id}:#{slug}",
        :backlinks_updated
      )
    end)

    Enum.each(target_pages, fn page ->
      Phoenix.PubSub.broadcast(
        Wik.PubSub,
        "backlinks:page:#{group_id}:#{page.id}",
        :backlinks_updated
      )
    end)
  end
end
