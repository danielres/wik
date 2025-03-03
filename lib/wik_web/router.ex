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

  pipeline :ensure_auth do
    plug WikWeb.Plugs.EnsureAuth
  end

  scope "/api", WikWeb do
    get "/pages_suggestions", PageController, :suggestions
  end

  scope "/admin", WikWeb do
    pipe_through [:browser, :ensure_superuser]

    live "/", SuperAdminLive.Index

    scope "/groups" do
      live "/", SuperAdmin.GroupLive.Index, :index
      live "/new", SuperAdmin.GroupLive.Index, :new
      live "/:id/edit", SuperAdmin.GroupLive.Index, :edit
      live "/:id/show/edit", SuperAdmin.GroupLive.Show, :edit
    end

    live "/revisions", SuperAdmin.RevisionLive.Index, :index
  end

  scope "/", WikWeb do
    pipe_through :browser

    scope "/auth" do
      post "/telegram/miniapp", TelegramAuthController, :miniapp
      get "/telegram/callback", TelegramAuthController, :callback
      get "/logout", SessionController, :logout
    end
  end

  scope "/", WikWeb do
    pipe_through [:browser, :ensure_auth]

    get "/", PageController, :root_index
    live "/me", Me.ShowLive

    scope "/:group_slug" do
      pipe_through [:ensure_group_membership]

      get "/", PageController, :group_index

      scope "/wiki" do
        get "/", PageController, :wiki_index
        live "/:slug", Page.ShowLive
        live "/:slug/revisions", Page.Revisions.ShowLive

        live_session :default do
          pipe_through [:handle_resource_lock]
          live "/:slug/edit", Page.EditLive
        end
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

  defp ensure_superuser(conn, _opts) do
    user = Plug.Conn.get_session(conn, :user)
    superuser_id = Application.get_env(:wik, :superuser_id)

    if user && user.id == superuser_id do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must be a superuser to access this page.")
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
    resource_path = Wik.Page.resource_path(group_slug, slug)

    userinfo = %{id: user.id, username: user.username}

    case Wik.ResourceLockServer.lock(resource_path, userinfo) do
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
