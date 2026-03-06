defmodule MetricFlow.Agencies do
  @moduledoc """
  Public API boundary for the Agencies bounded context.

  Manages agency-specific features: auto-enrollment rules, white-label
  configuration, team member management, and client account access grants.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation. The exception is `process_new_user_auto_enrollment/1`,
  which operates on behalf of a newly registered user with no active session.
  """

  use Boundary,
    deps: [MetricFlow],
    exports: [AutoEnrollmentRule, WhiteLabelConfig, AgencyClientAccessGrant]

  import Ecto.Query, only: [from: 2]

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies.AgenciesRepository
  alias MetricFlow.Agencies.AgencyClientAccessGrant
  alias MetricFlow.Agencies.AutoEnrollmentRule
  alias MetricFlow.Agencies.WhiteLabelConfig
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User

  @admin_roles [:owner, :admin]

  # ---------------------------------------------------------------------------
  # AutoEnrollmentRule
  # ---------------------------------------------------------------------------

  @doc """
  Configures domain-based auto-enrollment settings for an agency account.

  Requires admin access. Performs an upsert — if a rule already exists for
  the agency, it is updated. Returns `{:ok, rule}` on success or
  `{:error, changeset}` on validation failure.
  """
  @spec configure_auto_enrollment(Scope.t(), integer(), map()) ::
          {:ok, AutoEnrollmentRule.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def configure_auto_enrollment(%Scope{} = scope, agency_id, attrs) do
    with :ok <- authorize(scope, :admin, agency_id) do
      attrs_with_agency = Map.put(attrs, :agency_id, agency_id)

      case AgenciesRepository.get_auto_enrollment_rule(agency_id) do
        nil ->
          check_domain_uniqueness_then_insert(attrs_with_agency)

        existing ->
          AgenciesRepository.update_auto_enrollment_rule(existing, attrs_with_agency)
      end
    end
  end

  @doc """
  Retrieves the auto-enrollment configuration for an agency account.

  Requires read access. Returns the rule struct or nil when no rule exists.
  Returns `{:error, :unauthorized}` when the caller lacks read access.
  """
  @spec get_auto_enrollment_rule(Scope.t(), integer()) ::
          AutoEnrollmentRule.t() | nil | {:error, :unauthorized}
  def get_auto_enrollment_rule(%Scope{} = scope, agency_id) do
    with :ok <- authorize(scope, :read, agency_id) do
      AgenciesRepository.get_auto_enrollment_rule(agency_id)
    end
  end

  @doc """
  Evaluates whether a newly registered user should be auto-enrolled in an
  agency and creates the membership if a matching enabled rule is found.

  Extracts the email domain from the user's email, queries for active
  auto-enrollment rules matching that domain, and creates team memberships
  for all matching agencies. Idempotent — if the membership already exists
  it is returned without creating a duplicate.

  Returns `{:ok, [member]}` with created memberships or `{:ok, :no_match}`
  when no enabled rule matches the domain.
  """
  @spec process_new_user_auto_enrollment(User.t()) ::
          {:ok, list(AccountMember.t())} | {:ok, :no_match}
  def process_new_user_auto_enrollment(%User{email: email} = user) do
    domain = extract_email_domain(email)

    case AgenciesRepository.find_matching_rule(domain) do
      nil ->
        {:ok, :no_match}

      rule ->
        member = upsert_member_from_rule(user, rule)
        {:ok, [member]}
    end
  end

  # ---------------------------------------------------------------------------
  # Team member management
  # ---------------------------------------------------------------------------

  @doc """
  Adds a user to an agency team with the specified access level.

  Requires admin access to the agency account. Grants inherited access to all
  client accounts managed by the agency.

  Returns `{:ok, member}` on success or `{:error, changeset | :unauthorized}`
  on failure.
  """
  @spec add_agency_team_member(Scope.t(), integer(), integer(), atom()) ::
          {:ok, AccountMember.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def add_agency_team_member(%Scope{} = scope, agency_id, user_id, role) do
    with :ok <- authorize(scope, :admin, agency_id),
         :ok <- validate_agency_role(role),
         {:ok, member} <- insert_member(agency_id, user_id, role) do
      propagate_client_access_to_user(agency_id, user_id, role)
      {:ok, member}
    end
  end

  @doc """
  Lists all team members of an agency account.

  Requires admin access to the agency account. Returns members with user
  associations preloaded, ordered by most recently added first.
  """
  @spec list_agency_team_members(Scope.t(), integer()) ::
          list(AccountMember.t()) | {:error, :unauthorized}
  def list_agency_team_members(%Scope{} = scope, agency_id) do
    with :ok <- authorize(scope, :admin, agency_id) do
      AgenciesRepository.list_team_members(agency_id)
    end
  end

  @doc """
  Removes a user from an agency team and revokes their inherited client account
  access.

  Requires admin access to the agency account. Inherited access (granted via
  the agency) is revoked while direct (non-inherited) access is preserved.

  Returns `{:ok, deleted_member}` on success or `{:error, :not_found | :unauthorized}`.
  """
  @spec remove_agency_team_member(Scope.t(), integer(), integer()) ::
          {:ok, AccountMember.t()} | {:error, :not_found | :unauthorized}
  def remove_agency_team_member(%Scope{} = scope, agency_id, user_id) do
    with :ok <- authorize(scope, :admin, agency_id) do
      revoke_inherited_client_access(agency_id, user_id)
      AgenciesRepository.remove_team_member(agency_id, user_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Client account access
  # ---------------------------------------------------------------------------

  @doc """
  Lists all client accounts accessible to an agency.

  Requires read access to the agency account. Returns access grant records
  ordered by most recently created first.
  """
  @spec list_agency_client_accounts(Scope.t(), integer()) ::
          list(AgencyClientAccessGrant.t()) | {:error, :unauthorized}
  def list_agency_client_accounts(%Scope{} = scope, agency_id) do
    with :ok <- authorize(scope, :read, agency_id) do
      AgenciesRepository.list_client_accounts(agency_id)
    end
  end

  @doc """
  Retrieves an agency's access level and origination status for a specific
  client account.

  Requires read access to the agency account. Returns a map with access_level,
  origination_status, and a permissions map.

  Returns `{:ok, metadata}` on success or `{:error, :not_found | :unauthorized}`.
  """
  @spec get_client_account_access(Scope.t(), integer(), integer()) ::
          {:ok, map()} | {:error, :not_found | :unauthorized}
  def get_client_account_access(%Scope{} = scope, agency_id, client_account_id) do
    with :ok <- authorize(scope, :read, agency_id) do
      case AgenciesRepository.get_client_access(agency_id, client_account_id) do
        nil -> {:error, :not_found}
        grant -> {:ok, build_access_metadata(grant)}
      end
    end
  end

  @doc """
  Finds the first agency access grant for a given client account where the
  grant's agency account is one that the current user belongs to.

  Used by AccountLive.Index to display access level and origination status
  badges for accounts the user accesses via an agency grant. No authorization
  check beyond membership is required — the user's account IDs are already
  scoped to the current user.

  Returns the grant struct or nil when no matching grant exists.
  """
  @spec find_agency_grant_for_account(Scope.t(), integer(), list(integer())) ::
          AgencyClientAccessGrant.t() | nil
  def find_agency_grant_for_account(%Scope{}, client_account_id, user_account_ids) do
    AgenciesRepository.find_grant_for_user_client_account(client_account_id, user_account_ids)
  end

  @doc """
  Grants an agency access to a client account with the specified access level.

  Requires admin access to the agency account. Propagates access to all current
  agency team members. Sets `origination_status` to `:originator` when
  `is_originator` is true, otherwise `:invited`.

  Returns `{:ok, grant}` on success or `{:error, changeset | :unauthorized}`.
  """
  @spec grant_client_account_access(Scope.t(), integer(), integer(), atom(), boolean()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def grant_client_account_access(%Scope{} = scope, agency_id, client_account_id, access_level, is_originator) do
    with :ok <- authorize(scope, :admin, agency_id),
         {:ok, grant} <- do_grant_client_access(agency_id, client_account_id, access_level, is_originator) do
      propagate_client_access_to_team(agency_id, client_account_id, access_level)
      {:ok, grant}
    end
  end

  @doc """
  Revokes an agency's access to a client account.

  Requires admin access to the agency account. Also revokes access from all
  agency team members who received it via inheritance. Originator access cannot
  be revoked.

  Returns `{:ok, revoked_grant}` on success or
  `{:error, :cannot_revoke_originator | :not_found | :unauthorized}`.
  """
  @spec revoke_client_account_access(Scope.t(), integer(), integer()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, atom()}
  def revoke_client_account_access(%Scope{} = scope, agency_id, client_account_id) do
    with :ok <- authorize(scope, :admin, agency_id),
         :ok <- check_not_originator(agency_id, client_account_id),
         {:ok, grant} <- AgenciesRepository.revoke_client_access(agency_id, client_account_id) do
      revoke_team_client_access(agency_id, client_account_id)
      {:ok, grant}
    end
  end

  # ---------------------------------------------------------------------------
  # WhiteLabelConfig
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves white-label branding configuration for an agency.

  Requires read access to the agency account. Returns the config struct or nil
  when no config exists.
  """
  @spec get_white_label_config(Scope.t(), integer()) ::
          WhiteLabelConfig.t() | nil | {:error, :unauthorized}
  def get_white_label_config(%Scope{} = scope, agency_id) do
    with :ok <- authorize(scope, :read, agency_id) do
      AgenciesRepository.get_white_label_config(agency_id)
    end
  end

  @doc """
  Retrieves white-label configuration by subdomain.

  This is a public lookup that does not require authentication or scope,
  as it is used to apply branding to the layout for any request arriving
  on an agency's custom subdomain.

  Returns the config struct or nil when no config matches the subdomain.
  """
  @spec get_white_label_config_by_subdomain(String.t()) :: WhiteLabelConfig.t() | nil
  def get_white_label_config_by_subdomain(subdomain) do
    AgenciesRepository.get_white_label_config_by_subdomain(subdomain)
  end

  @doc """
  Resets (deletes) white-label branding configuration for an agency.

  Requires admin access to the agency account. Returns `:ok` on success or
  `{:error, :unauthorized}` when the caller lacks admin access.
  """
  @spec reset_white_label_config(Scope.t(), integer()) :: :ok | {:error, :unauthorized}
  def reset_white_label_config(%Scope{} = scope, agency_id) do
    with :ok <- authorize(scope, :admin, agency_id) do
      AgenciesRepository.delete_white_label_config(agency_id)
      :ok
    end
  end

  @doc """
  Creates or updates white-label branding configuration for an agency.

  Requires admin access to the agency account. Validates subdomain uniqueness
  and hex color formats.

  Returns `{:ok, config}` on success or `{:error, changeset | :unauthorized}`.
  """
  @spec update_white_label_config(Scope.t(), integer(), map()) ::
          {:ok, WhiteLabelConfig.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_white_label_config(%Scope{} = scope, agency_id, attrs) do
    with :ok <- authorize(scope, :admin, agency_id) do
      AgenciesRepository.upsert_white_label_config(agency_id, attrs)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — authorization
  # ---------------------------------------------------------------------------

  defp authorize(%Scope{user: user}, :admin, account_id) do
    role =
      from(m in AccountMember,
        where: m.user_id == ^user.id and m.account_id == ^account_id,
        select: m.role
      )
      |> Repo.one()

    if role in @admin_roles, do: :ok, else: {:error, :unauthorized}
  end

  defp authorize(%Scope{user: user}, :read, account_id) do
    member_exists =
      Repo.exists?(
        from(m in AccountMember,
          where: m.user_id == ^user.id and m.account_id == ^account_id
        )
      )

    if member_exists, do: :ok, else: {:error, :unauthorized}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — role validation
  # ---------------------------------------------------------------------------

  defp validate_agency_role(role) when role in [:read_only, :account_manager, :admin], do: :ok

  defp validate_agency_role(role) do
    changeset =
      %AccountMember{}
      |> AccountMember.changeset(%{account_id: 0, user_id: 0, role: role})

    {:error, changeset}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — member operations
  # ---------------------------------------------------------------------------

  defp insert_member(agency_id, user_id, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: agency_id, user_id: user_id, role: role})
    |> Repo.insert()
  end

  defp extract_email_domain(email) do
    [_local, domain] = String.split(email, "@", parts: 2)
    domain
  end

  # Idempotent: returns existing member if already enrolled, otherwise inserts.
  defp upsert_member_from_rule(%User{id: user_id}, %AutoEnrollmentRule{} = rule) do
    member =
      case Repo.get_by(AccountMember, account_id: rule.agency_id, user_id: user_id) do
        nil ->
          {:ok, inserted} = insert_member(rule.agency_id, user_id, rule.default_access_level)
          inserted

        existing ->
          existing
      end

    propagate_client_access_to_user(rule.agency_id, user_id, rule.default_access_level)
    member
  end

  # ---------------------------------------------------------------------------
  # Private helpers — domain uniqueness
  # ---------------------------------------------------------------------------

  defp check_domain_uniqueness_then_insert(attrs) do
    domain = Map.get(attrs, :email_domain)

    case AgenciesRepository.find_any_rule_for_domain(domain) do
      nil ->
        AgenciesRepository.create_auto_enrollment_rule(attrs)

      _existing ->
        changeset =
          %AutoEnrollmentRule{}
          |> AutoEnrollmentRule.changeset(attrs)
          |> Ecto.Changeset.add_error(:email_domain, "has already been taken")

        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — access metadata
  # ---------------------------------------------------------------------------

  defp build_access_metadata(%AgencyClientAccessGrant{} = grant) do
    %{
      access_level: grant.access_level,
      origination_status: grant.origination_status,
      permissions: build_permissions(grant.access_level)
    }
  end

  defp build_permissions(:read_only) do
    %{
      can_view_reports: true,
      can_modify_integrations: false,
      can_manage_users: false,
      can_delete_account: false
    }
  end

  defp build_permissions(:account_manager) do
    %{
      can_view_reports: true,
      can_modify_integrations: true,
      can_manage_users: false,
      can_delete_account: false
    }
  end

  defp build_permissions(:admin) do
    %{
      can_view_reports: true,
      can_modify_integrations: true,
      can_manage_users: true,
      can_delete_account: false
    }
  end

  defp build_permissions(:owner) do
    %{
      can_view_reports: true,
      can_modify_integrations: true,
      can_manage_users: true,
      can_delete_account: true
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers — grant operations
  # ---------------------------------------------------------------------------

  defp do_grant_client_access(agency_id, client_account_id, access_level, true) do
    case AgenciesRepository.grant_client_access(agency_id, client_account_id, access_level) do
      {:ok, _grant} -> AgenciesRepository.mark_as_originator(agency_id, client_account_id)
      {:error, _} = error -> error
    end
  end

  defp do_grant_client_access(agency_id, client_account_id, access_level, false) do
    AgenciesRepository.grant_client_access(agency_id, client_account_id, access_level)
  end

  defp check_not_originator(agency_id, client_account_id) do
    case AgenciesRepository.originated_by?(agency_id, client_account_id) do
      true -> {:error, :cannot_revoke_originator}
      false -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — access propagation
  # ---------------------------------------------------------------------------

  defp propagate_client_access_to_team(agency_id, client_account_id, access_level) do
    members = AgenciesRepository.list_team_members(agency_id)

    Enum.each(members, fn member ->
      insert_member_if_absent(client_account_id, member.user_id, access_level)
    end)
  end

  defp propagate_client_access_to_user(agency_id, user_id, role) do
    client_accounts = AgenciesRepository.list_client_accounts(agency_id)

    Enum.each(client_accounts, fn grant ->
      insert_member_if_absent(grant.client_account_id, user_id, role)
    end)
  end

  defp insert_member_if_absent(account_id, user_id, role) do
    case Repo.get_by(AccountMember, account_id: account_id, user_id: user_id) do
      nil ->
        %AccountMember{}
        |> AccountMember.changeset(%{account_id: account_id, user_id: user_id, role: role})
        |> Repo.insert()

      _existing ->
        :ok
    end
  end

  defp revoke_team_client_access(agency_id, client_account_id) do
    members = AgenciesRepository.list_team_members(agency_id)

    Enum.each(members, fn member ->
      from(m in AccountMember,
        where: m.account_id == ^client_account_id and m.user_id == ^member.user_id
      )
      |> Repo.delete_all()
    end)
  end

  defp revoke_inherited_client_access(agency_id, user_id) do
    client_accounts = AgenciesRepository.list_client_accounts(agency_id)

    Enum.each(client_accounts, fn grant ->
      from(m in AccountMember,
        where: m.account_id == ^grant.client_account_id and m.user_id == ^user_id
      )
      |> Repo.delete_all()
    end)
  end
end
