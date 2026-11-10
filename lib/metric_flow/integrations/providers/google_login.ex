defmodule MetricFlow.Integrations.Providers.GoogleLogin do
  @moduledoc """
  Google OAuth provider used only for "Continue with Google" sign-in.

  Requests identity scopes only (`email profile`), so Google's consent screen
  needs no app verification. Not registered in the integration provider map:
  signing in never creates an integration, and the Connect page must not list it.
  Analytics/Ads access is granted separately through `Providers.Google`.
  """

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @callback_path "/auth/google/callback"

  @impl true
  def config do
    [
      client_id: Application.fetch_env!(:metric_flow, :google_client_id),
      client_secret: Application.fetch_env!(:metric_flow, :google_client_secret),
      redirect_uri: MetricFlowWeb.Endpoint.url() <> @callback_path,
      authorization_params: [scope: "email profile"]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Google

  @impl true
  def normalize_user(%{"sub" => sub} = data) when is_binary(sub) and sub != "" do
    {:ok,
     %{
       provider_user_id: sub,
       email: data["email"],
       email_verified: data["email_verified"],
       name: data["name"],
       username: data["email"],
       avatar_url: data["picture"],
       hosted_domain: data["hd"]
     }}
  end

  def normalize_user(%{}), do: {:error, :missing_provider_user_id}
  def normalize_user(_), do: {:error, :invalid_user_data}
end
