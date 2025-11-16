defmodule Wik.Notifiers.ResourceMutation do
  use Ash.Notifier

  def notify(%Ash.Notifier.Notification{
        action: %{type: :update},
        changeset: changeset,
        resource: resource,
        data: data,
        actor: actor
      }) do
    # Only broadcast if there are actual attribute changes  
    updated_fields = Map.keys(changeset.attributes)

    if updated_fields != [] do
      resource_name = resource_name(resource)
      topic = "#{resource_name}:updated:#{data.id}"

      payload = %{
        data: data,
        changeset: changeset,
        actor: actor
      }

      Phoenix.PubSub.broadcast(
        Wik.PubSub,
        topic,
        %Phoenix.Socket.Broadcast{
          topic: topic,
          event: "update",
          payload: payload
        }
      )
    else
      :ok
    end
  end

  def notify(%Ash.Notifier.Notification{
        action: %{type: :create},
        resource: resource,
        data: data,
        actor: actor
      }) do
    resource_name = resource_name(resource)
    topic = "#{resource_name}:created:#{data.id}"

    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      topic,
      %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "create",
        payload: %{data: data, actor: actor}
      }
    )
  end

  def notify(%Ash.Notifier.Notification{
        action: %{type: :destroy},
        resource: resource,
        data: data,
        actor: actor
      }) do
    resource_name = resource_name(resource)
    topic = "#{resource_name}:destroyed:#{data.id}"

    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      topic,
      %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "destroy",
        payload: %{data: data, actor: actor}
      }
    )
  end

  def notify(_), do: :ok

  # Helper to extract a lowercase resource name from the module  
  defp resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
