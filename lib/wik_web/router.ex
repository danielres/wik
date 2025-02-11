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

    get "/:group_slug/wiki", PageController, :wiki_index

    get "/:group_slug/wiki/:slug", PageController, :show
    get "/:group_slug/wiki/:slug/edit", PageController, :edit
    post "/:group_slug/wiki/:slug", PageController, :update
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
