defmodule Wik.Notifiers.PageTreeMutation do
  use Ash.Notifier

  @tree_events [:create, :update, :destroy]

  def notify(%Ash.Notifier.Notification{action: %{type: type}} = notification)
      when type in @tree_events do
    group_id = extract_group_id(notification)

    case Wik.Wiki.PageTree.Utils.pages_tree_topic(group_id) do
      nil ->
        :ok

      topic ->
        Phoenix.PubSub.broadcast(Wik.PubSub, topic, {:pages_tree_updated, group_id})
    end
  end

  def notify(_), do: :ok

  defp extract_group_id(%Ash.Notifier.Notification{data: data, changeset: changeset}) do
    case Map.get(data, :group_id) do
      group_id when is_binary(group_id) and group_id != "" ->
        group_id

      _ ->
        case changeset do
          %Ash.Changeset{} ->
            case Ash.Changeset.get_attribute(changeset, :group_id) do
              group_id when is_binary(group_id) and group_id != "" ->
                group_id

              _ ->
                data_group_id(changeset.data)
            end

          _ ->
            nil
        end
    end
  end

  defp extract_group_id(%Ash.Notifier.Notification{data: data}) do
    data_group_id(data)
  end

  defp data_group_id(%{group_id: group_id}) when is_binary(group_id) and group_id != "" do
    group_id
  end

  defp data_group_id(_), do: nil
end
