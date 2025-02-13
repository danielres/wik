defmodule Wik do
  @moduledoc """
  Wik keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def get_group_title(group_slug) do
    all_groups = Application.get_env(:wik, :all_groups)
    Enum.find_value(all_groups, fn group -> group.slug == group_slug end, & &1.title)
  end
end
