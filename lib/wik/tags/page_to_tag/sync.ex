defmodule Wik.Tags.PageToTag.Sync do
  @moduledoc """
  Sync page tags on save: parse tags, upsert Tag records, and replace PageToTag rows.

  Best-effort: intended to be called in an after_transaction hook; errors are logged but should not block page save.
  """

  alias Wik.Tags.{PageToTag, Tag}
  import Ash.Query
  require Logger

  @spec sync(%{
          id: any(),
          group_id: any(),
          text: String.t()
        }) :: :ok | {:error, term()}
  def sync(%{id: page_id, group_id: group_id, text: text}) do
    tags = Utils.Markdown.extract_tags(text)

    Wik.Repo.transaction(fn ->
      tag_ids =
        tags
        |> Enum.map(&upsert_tag!(group_id, &1))

      replace_page_tags!(group_id, page_id, tag_ids)
    end)
    |> case do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to sync page tags",
          page_id: page_id,
          group_id: group_id,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp upsert_tag!(group_id, name) do
    {:ok, tag} =
      Tag
      |> Ash.Changeset.for_create(:create, %{group_id: group_id, name: name})
      |> Ash.create(
        upsert?: true,
        upsert_identity: :unique_group_name,
        upsert_fields: [:name],
        authorize?: false,
        return_notifications?: false
      )

    tag.id
  end

  defp replace_page_tags!(group_id, page_id, tag_ids) do
    # delete existing rows for this page+group
    PageToTag
    |> filter(group_id == ^group_id and page_id == ^page_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn row -> Ash.destroy!(row, authorize?: false, return_notifications?: false) end)

    # insert new rows
    Enum.each(tag_ids, fn tag_id ->
      {:ok, _} =
        PageToTag
        |> Ash.Changeset.for_create(:create, %{
          group_id: group_id,
          page_id: page_id,
          tag_id: tag_id
        })
        |> Ash.create(authorize?: false, return_notifications?: false)
    end)

    :ok
  end
end
