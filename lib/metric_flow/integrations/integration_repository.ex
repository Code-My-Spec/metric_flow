defmodule MetricFlow.Integrations.IntegrationRepository do
  @moduledoc """
  Data access layer for Integration CRUD operations filtered by account_id.

  All operations are scoped via the Scope struct for multi-tenant isolation.
  Provides upsert_integration/3 for OAuth callback handling,
  with_expired_tokens/1 for expiration queries, and connected?/2 for existence
  checks. Cloak handles automatic encryption/decryption of tokens.

  Also provides unscoped get_integration_by_id/1 and
  list_all_active_integrations/0 for background workers that need to operate
  without a user scope (e.g., the daily sync scheduler and SyncWorker).
  """

  import Ecto.Query

  alias MetricFlow.AccountAccess
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Query functions
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves the scope's account integration for the provider.

  Returns {:ok, integration} when found or {:error, :not_found} when absent.
  Cloak automatically decrypts access_token and refresh_token on load.
  """
  @spec get_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
  def get_integration(%Scope{} = scope, provider) do
    result =
      scope
      |> scoped_integrations()
      |> where([i], i.provider == ^provider)
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  @doc """
  Retrieves a single integration by its primary key ID without scope restriction.

  Intended for background worker use cases where only an integration_id is
  available and no user scope is present (e.g., SyncWorker.perform/1).
  Returns {:ok, integration} when found or {:error, :not_found} when absent.
  Cloak automatically decrypts access_token and refresh_token on load.
  """
  @spec get_integration_by_id(integer()) :: {:ok, Integration.t()} | {:error, :not_found}
  def get_integration_by_id(id) do
    case Repo.get(Integration, id) do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  @doc """
  Returns all integrations of the scope's account, ordered by most recently
  created. Every member of the account sees them.
  """
  @spec list_integrations(Scope.t()) :: list(Integration.t())
  def list_integrations(%Scope{} = scope) do
    scope
    |> scoped_integrations()
    |> order_by([i], desc: i.inserted_at, desc: i.id)
    |> Repo.all()
  end

  defp scoped_integrations(%Scope{} = scope) do
    AccountAccess.scope_query(Integration, scope)
  end

  @doc """
  Checks that the scope may change the account's integrations (connect,
  select, disconnect, sync): owner, admin or account_manager members, or a
  background system scope. The same rule applies to every provider.
  """
  @spec authorize_write(Scope.t(), atom()) :: :ok | {:error, :unauthorized}
  def authorize_write(%Scope{} = scope, _provider) do
    case AccountAccess.authorize_write(scope) do
      {:ok, _account_id} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Creates a new integration with encrypted tokens in the scope's account.

  Records the scope's user as the connector. Enforces the unique constraint
  on (account_id, provider).
  """
  @spec create_integration(Scope.t(), map()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def create_integration(%Scope{} = scope, attrs) do
    with {:ok, account_id} <- AccountAccess.authorize_write(scope) do
      attrs = Map.drop(attrs, [:user_id, :account_id, "user_id", "account_id"])

      %Integration{user_id: AccountAccess.user_id(scope), account_id: account_id}
      |> Integration.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Updates an existing integration with new attributes.

  Fetches the integration first using get_integration/2. Returns
  {:error, :not_found} when no integration exists for the scoped user and
  provider. Commonly used for token refresh operations.
  """
  @spec update_integration(Scope.t(), atom(), map()) ::
          {:ok, Integration.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_integration(%Scope{} = scope, provider, attrs) do
    with :ok <- authorize_write(scope, provider),
         {:ok, integration} <- get_integration(scope, provider) do
      attrs = Map.drop(attrs, [:user_id, :account_id, "user_id", "account_id"])

      integration
      |> Integration.changeset(attrs)
      # Validate supplied provider values while keeping the stored identity immutable.
      |> Ecto.Changeset.delete_change(:provider)
      |> Repo.update()
    end
  end

  @doc """
  Removes an integration and all associated encrypted tokens.

  Fetches the integration first using get_integration/2. Returns
  {:error, :not_found} when no integration exists for the scoped user and
  provider.
  """
  @spec delete_integration(Scope.t(), atom()) ::
          {:ok, Integration.t()} | {:error, :not_found}
  def delete_integration(%Scope{} = scope, provider) do
    with :ok <- authorize_write(scope, provider),
         {:ok, integration} <- get_integration(scope, provider) do
      Repo.delete(integration)
    end
  end

  @doc """
  Deletes every integration belonging to the scope's account, regardless of
  provider.

  Used when the account through which these connections are managed is
  being deleted permanently.
  """
  @spec delete_all_integrations(Scope.t()) :: :ok
  def delete_all_integrations(%Scope{} = scope) do
    Integration
    |> AccountAccess.scope_query(scope)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Alias for get_integration/2 — provides semantic clarity when querying by
  provider name.
  """
  @spec by_provider(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
  def by_provider(%Scope{} = scope, provider) do
    get_integration(scope, provider)
  end

  @doc """
  Returns all integrations for the scoped user where expires_at is less than
  the current UTC timestamp.

  Used to identify integrations requiring token refresh.
  """
  @spec with_expired_tokens(Scope.t()) :: list(Integration.t())
  def with_expired_tokens(%Scope{} = scope) do
    now = DateTime.utc_now()

    scope
    |> scoped_integrations()
    |> where([i], i.expires_at < ^now)
    |> Repo.all()
  end

  @doc """
  Creates or updates the scope's account integration for `provider`, based on
  the unique (account_id, provider) constraint -- one connection per provider
  per account, whoever connects it.

  On reconnect the tokens and scopes are replaced (user_id keeps recording
  who first connected it), a missing refresh token keeps the stored one, and provider_metadata is merged so
  saved selections (property, site, location, channels...) survive.
  """
  @spec upsert_integration(Scope.t(), atom(), map()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def upsert_integration(%Scope{} = scope, provider, attrs) do
    with {:ok, account_id} <- AccountAccess.authorize_write(scope) do
      attrs =
        Map.drop(attrs, [:user_id, :account_id, :provider, "user_id", "account_id", "provider"])

      %Integration{
        user_id: AccountAccess.user_id(scope),
        account_id: account_id,
        provider: provider
      }
      |> Integration.changeset(attrs)
      |> Repo.insert(
        on_conflict: reconnect_update(),
        conflict_target: [:account_id, :provider],
        returning: true
      )
    end
  end

  defp reconnect_update do
    from(i in Integration,
      update: [
        set: [
          access_token: fragment("EXCLUDED.access_token"),
          refresh_token: fragment("COALESCE(EXCLUDED.refresh_token, ?)", i.refresh_token),
          expires_at: fragment("EXCLUDED.expires_at"),
          granted_scopes: fragment("EXCLUDED.granted_scopes"),
          provider_metadata:
            fragment(
              "COALESCE(?, '{}'::jsonb) || EXCLUDED.provider_metadata",
              i.provider_metadata
            ),
          reconnection_notified_at: fragment("EXCLUDED.reconnection_notified_at"),
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ]
    )
  end

  @doc """
  Returns true if an integration exists for the scoped user and provider,
  false otherwise.

  Performs an efficient existence check without loading the full record.
  """
  @spec connected?(Scope.t(), atom()) :: boolean()
  def connected?(%Scope{} = scope, provider) do
    scope
    |> scoped_integrations()
    |> where([i], i.provider == ^provider)
    |> Repo.exists?()
  end

  @doc """
  Returns all integrations across all users, excluding those with expired
  tokens that have no refresh token available.

  Intended for the daily sync scheduler which operates across all users and
  has no user scope context. Only integrations with valid tokens or with a
  refresh token are returned so the scheduler does not enqueue jobs that will
  immediately fail due to unrecoverable token expiry.
  """
  @spec list_all_active_integrations() :: list(Integration.t())
  def list_all_active_integrations do
    # Legacy rows whose owner has not been assigned yet have no account and
    # cannot be synced on anyone's behalf.
    from(i in Integration, where: not is_nil(i.account_id))
    |> Repo.all()
  end
end
