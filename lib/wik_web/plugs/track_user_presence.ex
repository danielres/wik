defmodule WikWeb.Plugs.TrackUserPresence do
  @moduledoc """
  Plug to track user presence by updating the last_seen timestamp.
  This plug should be used after EnsureAuth to ensure the user is authenticated.
  """
  alias Wik.Users

  def init(opts), do: opts

  def call(conn, _opts) do
    if user = conn.assigns[:user] do
      dbg(user)
      Users.update_last_seen(user.id)
    end

    conn
  end
end
