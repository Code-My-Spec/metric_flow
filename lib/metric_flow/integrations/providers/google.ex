defmodule MetricFlow.Integrations.Providers.Google do
  @moduledoc """
  Google OAuth provider implementation using Assent.Strategy.Google.

  Configures OAuth with `email`, `profile`, and `analytics.edit` scopes,
  requesting offline access with a forced consent prompt to ensure a refresh
  token is issued on every authorisation. Normalizes Google user data
  (delivered as OpenID Connect claims) to the application domain model,
  mapping string-keyed OIDC fields to atom-keyed domain fields and including
  the `hosted_domain` field for Google Workspace accounts.
  """

  require Logger

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @callback_path "/auth/google/callback"

  # ---------------------------------------------------------------------------
  # Behaviour implementation
  # ---------------------------------------------------------------------------

  @doc """
  Returns the Assent strategy configuration keyword list for Google OAuth.

  Reads `:google_client_id` and `:google_client_secret` from application
  config under the `:metric_flow` key at call time, so values can be
  overridden in tests without recompilation.
  """
  @spec config() :: Keyword.t()
  @impl MetricFlow.Integrations.Providers.Behaviour
  def config do
    client_id = Application.fetch_env!(:metric_flow, :google_client_id)
    client_secret = Application.fetch_env!(:metric_flow, :google_client_secret)
    redirect_uri = build_redirect_uri()

    Logger.debug("Google OAuth config: client_id=#{client_id}, client_secret_set=#{client_secret != nil}, redirect_uri=#{redirect_uri}")

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "email profile analytics.edit",
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  @doc """
  Returns the Assent strategy module used for the Google OAuth flow.
  """
  @spec strategy() :: module()
  @impl MetricFlow.Integrations.Providers.Behaviour
  def strategy, do: Assent.Strategy.Google

  @doc """
  Transforms Google user data (OIDC claims) into the application domain model.

  Returns `{:ok, normalized}` with atom-keyed fields on success, or an error
  tuple when the input is invalid or the required `"sub"` claim is absent.

  The `hosted_domain` field is populated from the `"hd"` claim present in
  Google Workspace accounts; it will be `nil` for personal Gmail accounts.
  """
  @spec normalize_user(user_data :: map()) ::
          {:ok, map()}
          | {:error, :invalid_user_data}
          | {:error, :missing_provider_user_id}
          | {:error, :invalid_provider_user_id}
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
         avatar_url: Map.get(user_data, "picture"),
         hosted_domain: Map.get(user_data, "hd")
       }}
    end
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_redirect_uri do
    MetricFlowWeb.Endpoint.url() <> @callback_path
  end

  defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and byte_size(sub) > 0,
    do: {:ok, sub}

  defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub),
    do: {:ok, Integer.to_string(sub)}

  defp extract_provider_user_id(%{"sub" => nil}), do: {:error, :missing_provider_user_id}

  defp extract_provider_user_id(%{"sub" => _sub}), do: {:error, :invalid_provider_user_id}

  defp extract_provider_user_id(_user_data), do: {:error, :missing_provider_user_id}
end
