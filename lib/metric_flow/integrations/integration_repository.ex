defmodule MetricFlow.Integrations.IntegrationRepository do
  @moduledoc """
  Data access layer for Integration CRUD operations filtered by user_id.

  All operations are scoped via the Scope struct for multi-tenant isolation.
  Provides upsert_integration/3 for OAuth callback handling,
  with_expired_tokens/1 for expiration queries, and connected?/2 for existence
  checks. Cloak handles automatic encryption/decryption of tokens.

  Also provides unscoped get_integration_by_id/1 and
  list_all_active_integrations/0 for background workers that need to operate
  without a user scope (e.g., the daily sync scheduler and SyncWorker).
  """

  import Ecto.Query

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Query functions
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single integration for the scoped user and provider.

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
  Returns all integrations for the scoped user, ordered by most recently created.

  Returns an empty list when no integrations exist for the user.
  """
  @spec list_integrations(Scope.t()) :: list(Integration.t())
  def list_integrations(%Scope{} = scope) do
    scope
    |> scoped_integrations()
    |> order_by([i], desc: i.inserted_at, desc: i.id)
    |> Repo.all()
  end

  defp scoped_integrations(%Scope{user: user, account_id: account_id})
       when is_integer(account_id) do
    memberships =
      from(m in MetricFlow.Accounts.AccountMember,
        where: m.user_id == ^user.id and m.account_id == ^account_id,
        select: m.account_id
      )

    from(i in Integration,
      where:
        (i.provider != :youtube and i.user_id == ^user.id) or
          (i.provider == :youtube and i.account_id == ^account_id and
             i.account_id in subquery(memberships))
    )
  end

  defp scoped_integrations(%Scope{user: user}) do
    from(i in Integration, where: i.user_id == ^user.id and i.provider != :youtube)
  end

  def authorize_write(%Scope{user: user, account_id: account_id}, :youtube)
      when is_integer(account_id) do
    allowed =
      from(m in MetricFlow.Accounts.AccountMember,
        where:
          m.user_id == ^user.id and m.account_id == ^account_id and
            m.role in [:owner, :admin, :account_manager]
      )
      |> Repo.exists?()

    if allowed, do: :ok, else: {:error, :unauthorized}
  end

  def authorize_write(%Scope{}, :youtube), do: {:error, :unauthorized}
  def authorize_write(%Scope{}, _provider), do: :ok

  @doc """
  Creates a new integration with encrypted tokens.

  Merges user_id from the scope into attrs before inserting. Validates provider
  support and enforces the unique constraint on (user_id, provider).
  """
  @spec create_integration(Scope.t(), map()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def create_integration(%Scope{user: user}, attrs) do
    attrs_with_user = Map.put(attrs, :user_id, user.id)

    %Integration{}
    |> Integration.changeset(attrs_with_user)
    |> Repo.insert()
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
  Deletes every integration belonging to the scoped user, regardless of
  provider.

  Used when the account through which these connections are managed is
  being deleted permanently.
  """
  @spec delete_all_integrations(Scope.t()) :: :ok
  def delete_all_integrations(%Scope{user: user}) do
    from(i in Integration, where: i.user_id == ^user.id and i.provider != :youtube)
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
  def with_expired_tokens(%Scope{user: user}) do
    now = DateTime.utc_now()

    from(i in Integration,
      where: i.user_id == ^user.id and i.expires_at < ^now
    )
    |> Repo.all()
  end

  @doc """
  Creates or updates an integration based on the unique (user_id, provider)
  constraint.

  Merges user_id from the scope and the given provider into attrs before
  upserting. Used during OAuth callbacks for both first-time connections and
  reconnections.
  """
  @spec upsert_integration(Scope.t(), atom(), map()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def upsert_integration(%Scope{user: user, account_id: account_id} = scope, :youtube, attrs) do
    with :ok <- authorize_write(scope, :youtube) do
      attrs =
        Map.drop(attrs, [:user_id, :account_id, :provider, "user_id", "account_id", "provider"])

      %Integration{user_id: user.id, account_id: account_id, provider: :youtube}
      |> Integration.changeset(attrs)
      |> Repo.insert(
        on_conflict:
          {:replace,
           [
             :access_token,
             :refresh_token,
             :expires_at,
             :granted_scopes,
             :provider_metadata,
             :reconnection_notified_at,
             :updated_at
           ]},
        conflict_target: [:account_id, :provider],
        returning: true
      )
    end
  end

  def upsert_integration(%Scope{user: user}, provider, attrs) do
    attrs_with_user_and_provider =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:provider, provider)

    changeset = Integration.changeset(%Integration{}, attrs_with_user_and_provider)

    Repo.insert(changeset,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: {:unsafe_fragment, "(user_id, provider) WHERE provider <> 'youtube'"}
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
    Repo.all(Integration)
  end
end
