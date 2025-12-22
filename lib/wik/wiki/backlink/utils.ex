defmodule Wik.Wiki.Backlink.Utils do
  @moduledoc """
  Backlink management helpers for wiki pages.
  """

  require Ash.Query
  alias Wik.Wiki.Backlink
  alias Wik.Wiki.Page

  @doc """
  Parse markdown for backlink target ids.

  Only supports `[text](wikid:UUID)` links. Deduplicates results.
  """
  @spec parse_wikilink_ids(String.t() | nil) :: MapSet.t(String.t())
  def parse_wikilink_ids(markdown) do
    markdown = markdown || ""

    Regex.scan(~r/\[[^\]]*\]\(wikid:([^\)]+)\)/, markdown, capture: :all_but_first)
    |> Enum.map(&hd/1)
    |> Enum.map(&normalize_id/1)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp normalize_id(id) do
    id
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
    ids = parse_wikilink_ids(page.text)

    if MapSet.size(ids) == 0 do
      do_rebuild(page, MapSet.new())
    else
      do_rebuild(page, ids)
    end
  end

  defp do_rebuild(page, ids) do
    {:ok, existing} =
      Backlink
      |> Ash.Query.filter(source_page_id == ^page.id and group_id == ^page.group_id)
      |> Ash.read(authorize?: false)

    existing_ids =
      existing
      |> Enum.map(& &1.target_page_id)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    to_delete =
      Enum.filter(existing, fn bl ->
        is_nil(bl.target_page_id) or bl.target_page_id not in ids
      end)

    to_create = MapSet.difference(ids, existing_ids)

    Enum.each(to_delete, fn backlink -> Ash.destroy!(backlink, authorize?: false) end)

    target_pages =
      if MapSet.size(to_create) > 0 do
        Page
        |> Ash.Query.filter(group_id == ^page.group_id and id in ^MapSet.to_list(to_create))
        |> Ash.read!(authorize?: false)
        |> Map.new(fn p -> {p.id, p} end)
      else
        %{}
      end

    Enum.each(to_create, fn id ->
      target_page = target_pages[id]
      target_page_id = target_page && target_page.id
      target_slug = target_page && target_page.slug

      if target_page_id do
        Backlink
        |> Ash.Changeset.for_create(
          :create,
          %{
            group_id: page.group_id,
            source_page_id: page.id,
            target_slug: target_slug,
            target_page_id: target_page_id
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)
      end
    end)

    broadcast_updates(page.group_id, ids)
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
      broadcast_updates(page.group_id, [page.id])
    end

    :ok
  end

  @doc """
  List backlinks pointing to a page (by id or slug), scoped to group.
  """
  @spec list_for_page(Page.t()) :: [Backlink.t()]
  def list_for_page(%Page{} = page) do
    Backlink
    |> Ash.Query.filter(group_id == ^page.group_id and target_page_id == ^page.id)
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

  defp broadcast_updates(group_id, target_ids) do
    Enum.each(target_ids, fn id ->
      Phoenix.PubSub.broadcast(
        Wik.PubSub,
        "backlinks:page:#{group_id}:#{id}",
        :backlinks_updated
      )
    end)
  end
end
