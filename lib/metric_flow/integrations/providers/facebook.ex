defmodule MetricFlow.Integrations.Providers.Facebook do
  @moduledoc """
  Facebook OAuth provider implementation using Assent.Strategy.Facebook.

  Configures OAuth with `email` and `ads_read` scopes for accessing Facebook
  Ads data. Normalizes Facebook user data to the application domain model.
  """

  require Logger

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @callback_path "/app/integrations/oauth/callback/facebook_ads"

  @impl MetricFlow.Integrations.Providers.Behaviour
  def config do
    client_id = Application.fetch_env!(:metric_flow, :facebook_app_id)
    client_secret = Application.fetch_env!(:metric_flow, :facebook_app_secret)
    redirect_uri = build_redirect_uri()

    Logger.debug(
      "Facebook OAuth config: client_id=#{client_id}, redirect_uri=#{redirect_uri}"
    )

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "ads_read"
      ]
    ]
  end

  @impl MetricFlow.Integrations.Providers.Behaviour
  def strategy, do: Assent.Strategy.Facebook

  @impl MetricFlow.Integrations.Providers.Behaviour
  def normalize_user(user_data) when is_map(user_data) do
    with {:ok, provider_user_id} <- extract_provider_user_id(user_data) do
      email = Map.get(user_data, "email")

      {:ok,
       %{
         provider_user_id: provider_user_id,
         email: email,
         name: Map.get(user_data, "name"),
         username: email,
         avatar_url: Map.get(user_data, "picture")
       }}
    end
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  defp build_redirect_uri do
    MetricFlowWeb.Endpoint.url() <> @callback_path
  end

  defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and byte_size(sub) > 0,
    do: {:ok, sub}

  defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub),
    do: {:ok, Integer.to_string(sub)}

  defp extract_provider_user_id(_user_data), do: {:error, :missing_provider_user_id}
end
