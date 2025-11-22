defmodule Wik.Notifiers.ResourceMutation do
  @moduledoc """
  Broadcasts resource mutations (create, update, destroy) via Phoenix PubSub.

  This notifier is used by Ash resources to broadcast changes in real-time,
  enabling LiveViews to react to updates from other users.

  ## Topics

  For each mutation, broadcasts to two topics:
  - Specific item: `{resource}:{action}:{id}` - for individual item subscriptions
  - Collection: `{resource}:{action}` - for list/index page subscriptions

  ## Events

  - `create` - When a resource is created
  - `update` - When a resource is updated (only if attributes changed)
  - `destroy` - When a resource is destroyed
  """

  use Ash.Notifier

  @doc """
  Handles update notifications.

  Only broadcasts if there are actual attribute changes to avoid
  unnecessary network traffic.
  """
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

  @doc """
  Handles create notifications.

  Broadcasts to both item-specific and collection topics.
  """
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

  @doc """
  Handles destroy notifications.

  Broadcasts to both item-specific and collection topics.
  """
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

  @doc """
  Fallback for unhandled notification types.
  """
  def notify(_), do: :ok

  @doc """
  Extracts a lowercase, underscored resource name from the module.

  ## Examples

      iex> resource_name(Wik.Accounts.Group)
      "group"

      iex> resource_name(Wik.Wiki.Page)
      "page"
  """
  @spec resource_name(module()) :: String.t()
  defp resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
