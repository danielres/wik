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
    text = text || ""

    tags =
      text
      |> Utils.Markdown.extract_tags()
      |> Enum.uniq()

    Wik.Repo.transaction(fn ->
      {tag_ids, notifications} = upsert_tags(group_id, tags)
      replace_page_tags!(group_id, page_id, tag_ids, notifications)
    end)
    |> case do
      {:ok, notifications} ->
        if notifications != [] do
          Ash.Notifier.notify(notifications)
        end

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

  defp upsert_tags(group_id, tags) do
    {tag_ids, notifications} =
      Enum.reduce(tags, {[], []}, fn name, {ids, notifications} ->
        {:ok, tag, new_notifications} =
          Tag
          |> Ash.Changeset.for_create(:create, %{group_id: group_id, name: name})
          |> Ash.create(
            upsert?: true,
            upsert_identity: :unique_group_name,
            upsert_fields: [:name],
            authorize?: false,
            return_notifications?: true
          )

        {[tag.id | ids], notifications ++ new_notifications}
      end)

    {Enum.reverse(tag_ids), notifications}
  end

  defp replace_page_tags!(group_id, page_id, tag_ids, notifications) do
    bulk_result =
      PageToTag
      |> filter(group_id == ^group_id and page_id == ^page_id)
      |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false, return_notifications?: true)

    notifications = notifications ++ bulk_result.notifications

    Enum.reduce(tag_ids, notifications, fn tag_id, notifications ->
      case PageToTag
           |> Ash.Changeset.for_create(:create, %{
             group_id: group_id,
             page_id: page_id,
             tag_id: tag_id
           })
           |> Ash.create(authorize?: false, return_notifications?: true) do
        {:ok, _page_to_tag, new_notifications} ->
          notifications ++ new_notifications

        {:error, reason} ->
          raise "Failed to create PageToTag: #{inspect(reason)}"
      end
    end)
  end
end
