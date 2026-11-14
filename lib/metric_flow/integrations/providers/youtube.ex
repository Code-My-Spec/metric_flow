defmodule MetricFlow.Integrations.Providers.YouTube do
  @moduledoc "Google OAuth provider for read-only YouTube access."
  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @required_scopes [
    "https://www.googleapis.com/auth/youtube.readonly",
    "https://www.googleapis.com/auth/yt-analytics.readonly"
  ]
  @revenue_scope "https://www.googleapis.com/auth/yt-analytics-monetary.readonly"

  def required_scopes, do: @required_scopes
  def revenue_scope, do: @revenue_scope

  @impl true
  def config do
    [
      client_id: Application.fetch_env!(:metric_flow, :google_client_id),
      client_secret: Application.fetch_env!(:metric_flow, :google_client_secret),
      redirect_uri: MetricFlowWeb.Endpoint.url() <> "/app/integrations/oauth/callback/youtube",
      authorization_params: [
        scope: Enum.join(["email", "profile"] ++ @required_scopes ++ [@revenue_scope], " "),
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Google

  @impl true
  defdelegate normalize_user(user), to: MetricFlow.Integrations.Providers.Google
end
