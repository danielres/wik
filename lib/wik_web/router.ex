defmodule WikWeb.Router do
  use WikWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WikWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", WikWeb do
    get "/pages_suggestions", PageController, :suggestions
  end

  scope "/", WikWeb do
    pipe_through :browser

    get "/auth/telegram/callback", TelegramAuthController, :callback
    get "/auth/logout", SessionController, :logout

    get "/", PageController, :home
  end

  scope "/:group_slug", WikWeb do
    pipe_through [:browser, :ensure_auth, :ensure_group_membership]

    get "/", PageController, :group_index

    scope "/wiki" do
      get "/", PageController, :wiki_index
      live "/:slug", Page.ShowLive

      live_session :default do
        pipe_through [:handle_resource_lock]
        live "/:slug/edit", Page.EditLive
      end
    end
  end

  if Application.compile_env(:wik, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      # Fake auth for development
      get "/auth", WikWeb.SessionController, :dev_login

      # Enable LiveDashboard and Swoosh mailbox preview in development
      live_dashboard "/dashboard", metrics: WikWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp ensure_auth(conn, _opts) do
    user = Plug.Conn.get_session(conn, :user)

    if user do
      conn |> assign(:user, user)
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must be logged in to access this page.")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end

  defp ensure_group_membership(conn, _opts) do
    user = conn.assigns.user
    group_slug = conn.params["group_slug"]
    membership? = Enum.any?(user.member_of, fn group -> group.slug == group_slug end)

    if membership? do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You are not authorized to access this group.")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end

  defp handle_resource_lock(conn, _opts) do
    user = conn.assigns.user
    group_slug = conn.params["group_slug"]
    slug = conn.params["slug"]
    resource_path = "#{group_slug}/wiki/#{slug}"

    case Wik.ResourceLockServer.lock(resource_path, user.id) do
      :ok ->
        conn

      {:error, reason} ->
        conn
        |> Phoenix.Controller.put_flash(:error, reason)
        |> Phoenix.Controller.redirect(to: "/#{group_slug}/wiki/#{slug}")
        |> halt()
    end
  end
end
