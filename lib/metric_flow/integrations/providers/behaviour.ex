defmodule MetricFlow.Integrations.Providers.Behaviour do
  @moduledoc """
  Behaviour contract that all OAuth provider implementations must satisfy.

  Providers return Assent strategy configuration via `config/0`, specify their
  Assent strategy module via `strategy/0`, and transform provider-specific user
  data into the application's domain model via `normalize_user/1`.

  This separation of concerns enables the OAuth flow to delegate to Assent's
  battle-tested strategy implementations while keeping domain normalization
  isolated inside each provider module.
  """

  @doc """
  Returns the Assent strategy configuration keyword list for this provider.

  Must include at minimum `:client_id`, `:client_secret`, and `:redirect_uri`.
  Provider-specific keys such as `:authorization_params` may also be included.
  """
  @callback config() :: Keyword.t()

  @doc """
  Returns the Assent strategy module to use for this provider.

  Examples: `Assent.Strategy.Github`, `Assent.Strategy.Google`.
  """
  @callback strategy() :: module()

  @doc """
  Transforms provider-specific user data into the application's domain model.

  Accepts a map of string-keyed claims from the OAuth provider and returns
  `{:ok, normalized}` on success or `{:error, reason}` on failure.

  The returned map must use atom keys and include at minimum:
  `:provider_user_id`, `:email`, `:name`, `:username`, `:avatar_url`.

  The `:provider_user_id` is sourced from the `"sub"` claim (OIDC standard)
  and is always returned as a binary string. All other claims are optional and
  will be `nil` when absent.
  """
  @callback normalize_user(user_data :: map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Revokes an access or refresh token with the provider's revocation endpoint.

  Accepts the token string to revoke. Returns `:ok` on success or
  `{:error, reason}` on failure. Optional — defaults to `:ok` (no-op)
  for providers that don't support or require token revocation.
  """
  @callback revoke_token(token :: String.t()) :: :ok | {:error, term()}

  @optional_callbacks [revoke_token: 1]
end
