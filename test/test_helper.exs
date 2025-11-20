ExUnit.configure(formatters: [ExUnit.CLIFormatter, ExUnitNotifier])
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Wik.Repo, :manual)

# IO.puts("MIX_ENV=#{Mix.env()}")
# IO.inspect(Application.get_env(:wik, Wik.Repo), label: "repo config")
# IO.inspect(System.get_env("DATABASE_URL"), label: "DATABASE_URL")
