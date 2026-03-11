defmodule MetricFlowWeb.Router do
  use MetricFlowWeb, :router

  import MetricFlowWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MetricFlowWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => "default-src 'self'"}
    plug :fetch_current_scope_for_user
    plug MetricFlowWeb.Plugs.WhiteLabel
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Prometheus metrics endpoint (ADR: monitoring_observability)
  scope "/" do
    get "/metrics", PromEx.Plug, prom_ex_module: MetricFlowWeb.PromEx
  end

  scope "/", MetricFlowWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
  end

  # Health check for Caddy reverse proxy and Docker healthcheck
  scope "/" do
    get "/health", MetricFlowWeb.HealthController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", MetricFlowWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:metric_flow, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MetricFlowWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MetricFlowWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {MetricFlowWeb.UserAuth, :require_authenticated},
        {MetricFlowWeb.WhiteLabelHook, :load_white_label},
        {MetricFlowWeb.ActiveAccountHook, :load_active_account}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/accounts", AccountLive.Index, :index
      live "/accounts/members", AccountLive.Members, :index
      live "/accounts/settings", AccountLive.Settings, :index
      live "/accounts/invitations", InvitationLive.Send, :index

      # Integration routes (LiveView)
      live "/integrations", IntegrationLive.Index, :index
      live "/integrations/connect", IntegrationLive.Connect, :index
      live "/integrations/connect/:provider", IntegrationLive.Connect, :detail
      live "/integrations/connect/:provider/accounts", IntegrationLive.Connect, :accounts
      live "/integrations/:provider/accounts/edit", IntegrationLive.AccountEdit, :edit
      live "/integrations/sync-history", IntegrationLive.SyncHistory, :index

      # Dashboard routes
      live "/dashboard", DashboardLive.Show, :index
      live "/dashboards/new", DashboardLive.Editor, :new
      live "/dashboards/:id/edit", DashboardLive.Editor, :edit
      live "/dashboards/:id", DashboardLive.Show, :show

      # Correlation routes
      live "/correlations", CorrelationLive.Index, :index

      # AI routes
      live "/insights", AiLive.Insights, :index
      live "/chat", AiLive.Chat, :index
      live "/chat/:id", AiLive.Chat, :show
    end

    # OAuth provider integration routes (controller — handles session_params)
    get "/integrations/oauth/:provider", IntegrationOAuthController, :request
    get "/integrations/oauth/callback/:provider", IntegrationOAuthController, :callback

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", MetricFlowWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{MetricFlowWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/onboarding", OnboardingLive, :index

      # Invitation acceptance — accessible to both authenticated and unauthenticated users
      live "/invitations/:token", InvitationLive.Accept, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
