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
    pipe_through [:browser, :ensure_group_membership]

    get "/", PageController, :group_index

    scope "/wiki" do
      get "/", PageController, :wiki_index
      live "/:slug", PageLive, :show
      get "/:slug/edit", PageController, :edit
      post "/:slug", PageController, :update
    end
  end

  defp ensure_group_membership(conn, _opts) do
    user = Plug.Conn.get_session(conn, :user)
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

  # Other scopes may use custom stacks.
  # scope "/api", WikWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wik, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WikWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
