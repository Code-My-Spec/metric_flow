defmodule MetricFlow.Integrations.Providers.Behaviour do
  @moduledoc """
  Defines the contract that all OAuth provider implementations must implement.

  Each provider (GitHub, GitLab, Bitbucket) implements these callbacks to provide
  Assent strategy configuration and normalize provider-specific user data to the
  application domain model.

  This behaviour leverages Assent's built-in OAuth strategies (`Assent.Strategy.Github`,
  `Assent.Strategy.Gitlab`, `Assent.Strategy.Bitbucket`) rather than reimplementing
  OAuth flows. Providers configure the Assent strategy and handle provider-specific
  concerns like user data normalization.

  ## Callbacks

  - `config/0` - Returns Assent strategy configuration for the provider
  - `strategy/0` - Returns the Assent strategy module to use
  - `normalize_user/1` - Transforms provider-specific user data to domain model

  ## Integration with Assent

  ### Request Phase

      provider = MetricFlow.Integrations.Providers.Github
      config = provider.config()
      strategy = provider.strategy()
      {:ok, %{url: url, session_params: session_params}} =
        strategy.authorize_url(config)
      # Store session_params for callback phase
      # Redirect user to url

  ### Callback Phase

      provider = MetricFlow.Integrations.Providers.Github
      config =
        provider.config()
        |> Keyword.put(:session_params, session_params)
      strategy = provider.strategy()
      {:ok, %{user: assent_user, token: token}} =
        strategy.callback(config, params)
      {:ok, normalized_user} = provider.normalize_user(assent_user)
      # Persist token and normalized_user

  ## Benefits

  - **Leverage Assent's expertise** - Use battle-tested OAuth implementations
  - **Minimal code** - Only implement provider-specific concerns
  - **Consistency** - All providers follow same OAuth flow
  - **Flexibility** - Easy to add new providers by implementing behaviour
  - **Separation of concerns** - OAuth mechanics handled by Assent, domain logic in providers
  """

  @doc """
  Returns the Assent strategy configuration for the provider.

  Configuration must include:
  - `:client_id` - OAuth client ID from provider
  - `:client_secret` - OAuth client secret from provider
  - `:redirect_uri` - OAuth callback URL
  - Provider-specific options (e.g., `:authorization_params` for custom scopes)

  Configuration values should be retrieved from application config or environment variables.

  ## Example

      def config do
        [
          client_id: Application.fetch_env!(:metric_flow, :github_client_id),
          client_secret: Application.fetch_env!(:metric_flow, :github_client_secret),
          redirect_uri: "http://localhost:4000/auth/github/callback",
          authorization_params: [scope: "user:email repo"]
        ]
      end
  """
  @callback config() :: Keyword.t()

  @doc """
  Returns the Assent strategy module to use for this provider.

  ## Example

      def strategy, do: Assent.Strategy.Github
  """
  @callback strategy() :: module()

  @doc """
  Transforms provider-specific user data into the application's domain model.

  Receives the raw user map from Assent (already normalized to OpenID Connect
  claims where possible) and returns application-specific user attributes.

  ## Example

      def normalize_user(user) do
        {:ok, %{
          provider_user_id: user["sub"],
          email: user["email"],
          name: user["name"],
          username: user["preferred_username"],
          avatar_url: user["picture"]
        }}
      end
  """
  @callback normalize_user(user_data :: map()) :: {:ok, map()} | {:error, term()}
end
