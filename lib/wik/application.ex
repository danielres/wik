defmodule Wik.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  @env Mix.env()

  @impl true
  def start(_type, _args) do
    children = [
      WikWeb.Telemetry,
      Wik.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:wik, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:wik, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Wik.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Wik.Finch},
      # Start a worker by calling: Wik.Worker.start_link(arg)
      # {Wik.Worker, arg},
      # Start to serve requests, typically the last entry
      WikWeb.Endpoint,
      {Wik.ResourceLockServer, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wik.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WikWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    @env !== :prod
  end
end
