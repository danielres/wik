defmodule Wik.Wiki.PageTree.Utils do
  @moduledoc """
  Helpers for resolving and validating page tree paths.
  """

  require Ash.Query
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.Page

  @invalid_title_regex ~r/[<>:"\/\\|?*\x00-\x1F\x7F]/u

  @spec normalize_path(String.t() | nil) :: {:ok, String.t(), String.t()} | {:error, String.t()}
  def normalize_path(nil), do: {:error, "path is required"}

  def normalize_path(path) when is_binary(path) do
    segments =
      path
      |> String.split("/", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case segments do
      [] ->
        {:error, "path is required"}

      _ ->
        with :ok <- validate_segments(segments) do
          normalized = Enum.join(segments, "/")
          {:ok, normalized, List.last(segments)}
        end
    end
  end

  @spec pages_tree_topic(String.t() | nil) :: String.t() | nil
  def pages_tree_topic(nil), do: nil

  def pages_tree_topic(group_id) when is_binary(group_id) do
    "pages_tree:#{group_id}"
  end


  @spec sanitize_segment(String.t() | nil) :: String.t()
  def sanitize_segment(nil), do: ""

  def sanitize_segment(segment) when is_binary(segment) do
    segment
    |> String.replace(@invalid_title_regex, "")
    |> String.trim()
  end

  @spec title_from_path(String.t() | nil) :: String.t()
  def title_from_path(nil), do: ""

  def title_from_path(path) when is_binary(path) do
    case normalize_path(path) do
      {:ok, _normalized, title} -> title
      _ -> ""
    end
  end

  @spec resolve_tree_by_path(String.t(), String.t(), any, map()) ::
          {:ok, PageTree.t(), map()} | {:error, String.t()}
  def resolve_tree_by_path(path, group_id, actor, path_map \\ %{}) do
    with {:ok, normalized, title} <- normalize_path(path) do
      case map_entry(path_map, normalized) do
        {:ok, entry} ->
          {:ok, entry, path_map}

        :error ->
          case PageTree
               |> Ash.Query.filter(group_id == ^group_id and path == ^normalized)
               |> Ash.read_one(actor: actor) do
            {:ok, %PageTree{} = tree} ->
              {:ok, tree, Map.put(path_map, normalized, tree)}

            {:ok, nil} ->
              create_tree(normalized, title, group_id, actor, path_map)

            {:error, _} ->
              create_tree(normalized, title, group_id, actor, path_map)
          end
      end
    end
  end

  @spec ensure_page_for_tree(PageTree.t(), any) :: {:ok, PageTree.t()} | {:error, any}
  def ensure_page_for_tree(%PageTree{page_id: page_id} = tree, _actor)
      when is_binary(page_id) and page_id != "" do
    {:ok, tree}
  end

  def ensure_page_for_tree(%PageTree{} = tree, actor) do
    with {:ok, nil} <- find_existing_page(tree) do
      changeset =
        Page
        |> Ash.Changeset.for_create(:create, %{title: tree.title, text: ""},
          actor: actor,
          context: %{shared: %{current_group_id: tree.group_id, raw_slug: true}}
        )
        |> Ash.Changeset.change_attribute(:slug, tree.path)

      case Ash.create(changeset, authorize?: false) do
        {:ok, page} ->
          tree
          |> Ash.Changeset.for_update(:update, %{page_id: page.id}, actor: actor)
          |> Ash.update(authorize?: false)
          |> case do
            {:ok, updated_tree} -> {:ok, updated_tree}
            {:error, _} -> {:ok, %{tree | page_id: page.id}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, %Page{} = page} ->
        tree
        |> Ash.Changeset.for_update(:update, %{page_id: page.id}, actor: actor)
        |> Ash.update(authorize?: false)
        |> case do
          {:ok, updated_tree} -> {:ok, updated_tree}
          {:error, _} -> {:ok, %{tree | page_id: page.id}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_existing_page(%PageTree{} = tree) do
    Page
    |> Ash.Query.filter(group_id == ^tree.group_id and slug == ^tree.path)
    |> Ash.read_one(authorize?: false)
  end

  defp validate_segments(segments) do
    case Enum.find(segments, &invalid_title?/1) do
      nil -> :ok
      _ -> {:error, "path contains invalid characters"}
    end
  end

  defp invalid_title?(segment) do
    segment == "" or String.match?(segment, @invalid_title_regex)
  end

  defp map_entry(path_map, normalized) do
    case Map.get(path_map, normalized) do
      nil -> :error
      %{id: _} = entry -> {:ok, entry}
      id when is_binary(id) -> {:ok, %{id: id, path: normalized}}
      entry -> {:ok, entry}
    end
  end

  defp create_tree(path, title, group_id, actor, path_map) do
    changeset =
      PageTree
      |> Ash.Changeset.for_create(:create, %{path: path, title: title, group_id: group_id},
        actor: actor
      )

    case Ash.create(changeset, authorize?: false) do
      {:ok, tree} ->
        {:ok, tree, Map.put(path_map, path, tree)}

      {:error, reason} ->
        {:error, Exception.message(reason)}
    end
  end
end
