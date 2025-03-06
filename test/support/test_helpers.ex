defmodule WikWeb.TestHelpers do
  @moduledoc """
  A collection of helper functions for end-to-end tests.
  """

  def tid(id) when is_binary(id), do: ~s( [data-test-id="#{id}"] )
  def tid(ids) when is_list(ids), do: Enum.map_join(ids, " ", &tid/1)
end
