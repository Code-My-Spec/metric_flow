defmodule MetricFlow.Integrations.Providers.QuickBooks do
  @moduledoc """
  QuickBooks Online OAuth provider implementation using Assent.Strategy.OAuth2.

  Configures OAuth with `com.intuit.quickbooks.accounting` scope for accessing
  QuickBooks Online company data. Uses the Intuit OAuth 2.0 endpoints for
  authorization and token exchange.
  """

  require Logger

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/quickbooks"

  @authorize_url "https://appcenter.intuit.com/connect/oauth2"
  @token_url "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
  @revoke_url "https://developer.api.intuit.com/v2/oauth2/tokens/revoke"

  # ---------------------------------------------------------------------------
  # Behaviour implementation
  # ---------------------------------------------------------------------------

  @doc """
  Returns the Assent strategy configuration keyword list for QuickBooks OAuth.

  Reads `:quickbooks_client_id` and `:quickbooks_client_secret` from application
  config under the `:metric_flow` key at call time, so values can be
  overridden in tests without recompilation.
  """
  @spec config() :: Keyword.t()
  @impl MetricFlow.Integrations.Providers.Behaviour
  def config do
    client_id = Application.fetch_env!(:metric_flow, :quickbooks_client_id)
    client_secret = Application.fetch_env!(:metric_flow, :quickbooks_client_secret)
    redirect_uri = build_redirect_uri()

    Logger.debug(
      "QuickBooks OAuth config: client_id=#{client_id}, client_secret_set=#{client_secret != nil}, redirect_uri=#{redirect_uri}"
    )

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      base_url: "https://oauth.platform.intuit.com",
      authorize_url: @authorize_url,
      token_url: @token_url,
      auth_method: :client_secret_basic,
      authorization_params: [
        scope: "com.intuit.quickbooks.accounting"
      ]
    ]
  end

  @doc """
  Returns the Assent strategy module used for the QuickBooks OAuth flow.
  """
  @spec strategy() :: module()
  @impl MetricFlow.Integrations.Providers.Behaviour
  def strategy, do: MetricFlow.Integrations.Strategies.QuickBooksOAuth2

  @doc """
  Transforms QuickBooks user data into the application domain model.

  QuickBooks OAuth2 token responses include a `realmId` query parameter
  identifying the connected company. The user info endpoint returns
  basic profile data.
  """
  @spec normalize_user(user_data :: map()) ::
          {:ok, map()}
          | {:error, :invalid_user_data}
          | {:error, :missing_provider_user_id}
          | {:error, :invalid_provider_user_id}
  @impl MetricFlow.Integrations.Providers.Behaviour
  def normalize_user(user_data) when is_map(user_data) do
    # When using the token-only strategy (no userinfo), user_data is %{}.
    # We use "sub" if available (from OpenID), otherwise generate a placeholder.
    # The realmId is attached separately via callback params.
    provider_user_id =
      case extract_provider_user_id(user_data) do
        {:ok, id} -> id
        {:error, _} -> "quickbooks_user"
      end

    email = Map.get(user_data, "email")

    {:ok,
     %{
       provider_user_id: provider_user_id,
       email: email,
       name: Map.get(user_data, "name") || Map.get(user_data, "givenName"),
       username: email,
       avatar_url: nil,
       realm_id: Map.get(user_data, "realmId")
     }}
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  @doc """
  Revokes a token (access or refresh) with the Intuit revocation endpoint.

  Uses Basic Auth (client_id:client_secret) as required by the Intuit API.
  Intuit's revocation endpoint returns plain text (not JSON), so the response
  is dispatched via `:httpc` to avoid Assent's JSON-decoding layer.
  """
  @spec revoke_token(String.t()) :: :ok | {:error, term()}
  @impl MetricFlow.Integrations.Providers.Behaviour
  def revoke_token(token) when is_binary(token) do
    client_id = Application.fetch_env!(:metric_flow, :quickbooks_client_id)
    client_secret = Application.fetch_env!(:metric_flow, :quickbooks_client_secret)
    credentials = Base.encode64("#{client_id}:#{client_secret}")
    body = Jason.encode!(%{"token" => token})

    headers = [
      {~c"authorization", ~c"Basic #{credentials}"},
      {~c"accept", ~c"application/json"},
      {~c"content-type", ~c"application/json"}
    ]

    request = {
      String.to_charlist(@revoke_url),
      headers,
      ~c"application/json",
      body
    }

    case :httpc.request(:post, request, [], []) do
      {:ok, {{_version, 200, _reason}, _headers, _body}} ->
        Logger.info("QuickBooks token revoked successfully")
        :ok

      {:ok, {{_version, status, _reason}, _headers, resp_body}} ->
        Logger.warning("QuickBooks token revocation returned #{status}: #{inspect(resp_body)}")
        {:error, {:revocation_failed, status}}

      {:error, reason} ->
        Logger.warning("QuickBooks token revocation request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

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
