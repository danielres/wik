import Config
config :wik, token_signing_secret: "BE4TchqeLk23dgshY5157kHtUZwrsl2g"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

# config :wik, Wik.Repo,
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   database: "wik_test#{System.get_env("MIX_TEST_PARTITION")}",
#   pool: Ecto.Adapters.SQL.Sandbox,
#   pool_size: System.schedulers_online() * 2

config :wik, Wik.Repo,
  username: "postgres",
  password: "postgres",
  # hostname: "localhost",
  # Use Unix socket instead:
  socket_dir: System.get_env("PGHOST"),
  database: "wik_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wik, WikWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "sSPwinKfRV2V30TjKxg3qw24ArX5He5rUjIV9nzHj7YFFoay4D0iYP5M/v7WJxgw",
  server: false

# In test we don't send emails
config :wik, Wik.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
