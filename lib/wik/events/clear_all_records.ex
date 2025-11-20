defmodule Wik.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(_opts) do
    # Logic to clear all relevant records for all resources with event tracking
    # enabled through the event log resource.
    :ok
  end
end
