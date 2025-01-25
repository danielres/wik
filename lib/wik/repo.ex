defmodule Wik.Repo do
  use Ecto.Repo,
    otp_app: :wik,
    adapter: Ecto.Adapters.SQLite3
end
