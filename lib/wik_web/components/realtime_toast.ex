defmodule WikWeb.Components.RealtimeToast do
  @moduledoc """
  Provides standardized toast messages for realtime updates.
  Automatically detects resource type and generates descriptive messages.
  """

  @doc """
  Shows a generic toast message for resource updates.
  Extracts resource type and name from payload automatically.
  """
  def put_update_toast(socket, payload) do
    message = format_message("updated", payload.data, payload.actor)
    Toast.put_toast(socket, :info, message)
  end

  @doc """
  Shows a generic toast message for resource creation.
  """
  def put_create_toast(socket, payload) do
    message = format_message("created", payload.data, payload.actor)
    Toast.put_toast(socket, :info, message)
  end

  @doc """
  Shows a generic toast message for resource deletion.
  """
  def put_delete_toast(socket, payload) do
    message = format_message("deleted", payload.data, payload.actor)
    Toast.put_toast(socket, :info, message)
  end

  defp format_message(action, resource_data, actor) do
    resource_type = get_resource_type(resource_data)
    resource_name = truncate_title(resource_data.title)

    "#{resource_type} \"#{resource_name}\" was just #{action} by #{actor}"
  end

  defp get_resource_type(resource_data) do
    resource_data.__struct__
    |> Module.split()
    |> List.last()
  end

  defp truncate_title(title, max_length \\ 50) do
    if String.length(title) > max_length do
      title
      |> String.slice(0, max_length - 3)
      |> Kernel.<>("...")
    else
      title
    end
  end
end
