defmodule MetricFlow.Integrations.Providers.GoogleBusiness do
  @moduledoc """
  Google Business Profile OAuth provider implementation.

  Uses Google OAuth with the `business.manage` scope for accessing
  Google Business Profile locations and reviews.
  """

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @callback_path "/app/integrations/oauth/callback/google_business"

  @impl true
  def config do
    client_id = Application.fetch_env!(:metric_flow, :google_client_id)
    client_secret = Application.fetch_env!(:metric_flow, :google_client_secret)
    redirect_uri = MetricFlowWeb.Endpoint.url() <> @callback_path

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope:
          "email profile https://www.googleapis.com/auth/business.manage",
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Google

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    MetricFlow.Integrations.Providers.Google.normalize_user(user_data)
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}
end
