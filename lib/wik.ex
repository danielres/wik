defmodule Wik do
  @moduledoc """
  Wik keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  # TODO: move get_group_name to Groups context
  def get_group_name(group_slug) do
    group = Wik.Groups.find_group_by_slug(group_slug)
    group.name
  end
end
