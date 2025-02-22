defmodule WikWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use WikWeb, :html

  @env Mix.env()

  def show_dev_login? do
    env = Atom.to_string(@env)
    env in ["dev", "test"]
  end

  embed_templates "page_html/*"
end
