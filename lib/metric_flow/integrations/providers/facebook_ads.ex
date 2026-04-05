defmodule MetricFlow.Integrations.Providers.FacebookAds do
  @moduledoc """
  Facebook Ads OAuth provider implementation.

  Configure the client credentials in your runtime config:

      config :metric_flow,
        facebook_ads_client_id: System.get_env("FACEBOOK_ADS_CLIENT_ID"),
        facebook_ads_client_secret: System.get_env("FACEBOOK_ADS_CLIENT_SECRET")
  """

  require Logger

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/facebook_ads"

  @impl true
  def config do
    client_id = Application.fetch_env!(:metric_flow, :facebook_ads_client_id)
    client_secret = Application.fetch_env!(:metric_flow, :facebook_ads_client_secret)
    redirect_uri = MetricFlowWeb.Endpoint.url() <> @callback_path

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "read"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.OAuth2

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    {:ok,
     %{
       provider_user_id: Map.get(user_data, "sub") || Map.get(user_data, "id") |> to_string(),
       email: Map.get(user_data, "email"),
       name: Map.get(user_data, "name"),
       username: Map.get(user_data, "login") || Map.get(user_data, "email"),
       avatar_url: Map.get(user_data, "avatar_url") || Map.get(user_data, "picture")
     }}
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}
end
