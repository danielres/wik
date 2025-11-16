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

      payload = %{
        data: data,
        changeset: changeset,
        actor: actor
      }

      # Broadcast to specific item topic (for show pages)  
      Phoenix.PubSub.broadcast(
        Wik.PubSub,
        "#{resource_name}:updated:#{data.id}",
        %Phoenix.Socket.Broadcast{
          topic: "#{resource_name}:updated:#{data.id}",
          event: "update",
          payload: payload
        }
      )

      # Also broadcast to collection topic (for index pages)  
      Phoenix.PubSub.broadcast(
        Wik.PubSub,
        "#{resource_name}:updated",
        %Phoenix.Socket.Broadcast{
          topic: "#{resource_name}:updated",
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
    payload = %{data: data, actor: actor}

    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      "#{resource_name}:created:#{data.id}",
      %Phoenix.Socket.Broadcast{
        topic: "#{resource_name}:created:#{data.id}",
        event: "create",
        payload: payload
      }
    )

    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      "#{resource_name}:created",
      %Phoenix.Socket.Broadcast{
        topic: "#{resource_name}:created",
        event: "create",
        payload: payload
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
    payload = %{data: data, actor: actor}

    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      "#{resource_name}:destroyed:#{data.id}",
      %Phoenix.Socket.Broadcast{
        topic: "#{resource_name}:destroyed:#{data.id}",
        event: "destroy",
        payload: payload
      }
    )

    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      "#{resource_name}:destroyed",
      %Phoenix.Socket.Broadcast{
        topic: "#{resource_name}:destroyed",
        event: "destroy",
        payload: payload
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
