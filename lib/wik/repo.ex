defmodule Wik.Repo do
  @moduledoc """
  PostgreSQL repository for the application.

  Configured to use AshPostgres with the following extensions:
  - `ash-functions` - Ash framework database functions
  - `citext` - Case-insensitive text type

  Requires PostgreSQL version 17.6.0 or higher.
  """
  use AshPostgres.Repo,
    otp_app: :wik

  @impl true
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "citext"]
  end

  @doc """
  Disables unnecessary transactions for better performance.

  This will be the default behavior in Ash 4.0.
  """
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 17, minor: 6, patch: 0}
  end
end
