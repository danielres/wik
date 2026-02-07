defmodule Wik.Wiki.Backlink.Utils do
  @moduledoc """
  Backlink management helpers for wiki pages.
  """

  require Ash.Query
  alias Wik.Wiki.Backlink
  alias Wik.Wiki.Page
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Utils, as: PageTreeUtils
  alias Wik.Accounts.User

  @doc """
  Rebuild backlinks for a page when its text changes. Runs inside the page action transaction.
  """
  @spec rebuild_for_page(Page.t(), Ash.Changeset.t()) :: :ok | {:error, term()}
  def rebuild_for_page(%Page{} = page, changeset) do
    ids = parse_wikilink_ids(page.text)
    actor = Map.get(changeset || %{}, :actor)

    targets =
      if MapSet.size(ids) == 0 do
        []
      else
        resolve_tree_targets(ids, page, actor)
      end

    do_rebuild(page, targets)
  end

  # INTERNAL ==================================================================

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

  defp do_rebuild(page, targets) do
    {:ok, existing} =
      Backlink
      |> Ash.Query.filter(source_page_id == ^page.id and group_id == ^page.group_id)
      |> Ash.read(authorize?: false)

    resolved_ids =
      targets
      |> Enum.map(& &1.page_id)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    to_delete =
      Enum.filter(existing, fn bl ->
        is_nil(bl.target_page_id) or bl.target_page_id not in resolved_ids
      end)

    to_create = MapSet.difference(resolved_ids, existing_ids(existing))

    Enum.each(to_delete, fn backlink -> Ash.destroy!(backlink, authorize?: false) end)

    target_lookup = Map.new(targets, &{&1.page_id, &1.path})

    Enum.each(to_create, fn id ->
      target_slug = Map.get(target_lookup, id, "")

      Backlink
      |> Ash.Changeset.for_create(
        :create,
        %{
          group_id: page.group_id,
          source_page_id: page.id,
          target_slug: target_slug,
          target_page_id: id
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
    end)

    broadcast_updates(page.group_id, resolved_ids)
    :ok
  end

  @doc """
  When a new page is created, reconcile any backlinks that pointed at its path.
  """
  @spec reconcile_new_target(Page.t()) :: :ok
  def reconcile_new_target(%Page{} = page) do
    tree =
      PageTree
      |> Ash.Query.filter(group_id == ^page.group_id and page_id == ^page.id)
      |> Ash.Query.select([:path])
      |> Ash.read_one(authorize?: false)

    case tree do
      {:ok, %PageTree{path: path}} ->
        {:ok, backlinks} =
          Backlink
          |> Ash.Query.filter(
            group_id == ^page.group_id and target_slug == ^path and is_nil(target_page_id)
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

      _ ->
        :ok
    end
  end

  @doc """
  List backlinks pointing to a page (by id), scoped to group.
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

  defp existing_ids(existing) do
    existing
    |> Enum.map(& &1.target_page_id)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp resolve_tree_targets(tree_ids, page, actor) do
    stub_actor = actor || fallback_actor(page)

    tree_ids
    |> Enum.reduce([], fn tree_id, acc ->
      case PageTree |> Ash.get(tree_id, authorize?: false) do
        {:ok, tree} ->
          case PageTreeUtils.ensure_page_for_tree(tree, stub_actor) do
            {:ok, updated_tree} when is_binary(updated_tree.page_id) ->
              [%{page_id: updated_tree.page_id, path: updated_tree.path} | acc]

            _ ->
              acc
          end

        _ ->
          acc
      end
    end)
  end

  defp fallback_actor(%Page{author_id: author_id}) when is_binary(author_id) do
    %User{id: author_id}
  end

  defp fallback_actor(_page), do: nil
end
