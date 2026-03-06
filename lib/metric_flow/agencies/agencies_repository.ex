defmodule MetricFlow.Agencies.AgenciesRepository do
  @moduledoc """
  Data access layer for agency features.

  Handles CRUD for auto-enrollment rules, white-label configs, team members
  via AccountMember, and client account access via AgencyClientAccessGrant.
  All operations query the database directly via MetricFlow.Repo.
  """

  import Ecto.Query

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies.AgencyClientAccessGrant
  alias MetricFlow.Agencies.AutoEnrollmentRule
  alias MetricFlow.Agencies.WhiteLabelConfig
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # AutoEnrollmentRule queries
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves the auto-enrollment rule for a specific agency account.

  Returns the matching rule or nil when no rule exists for the given agency_id.
  """
  @spec get_auto_enrollment_rule(integer()) :: AutoEnrollmentRule.t() | nil
  def get_auto_enrollment_rule(agency_id) do
    from(r in AutoEnrollmentRule,
      where: r.agency_id == ^agency_id
    )
    |> Repo.one()
  end

  @doc """
  Lists all auto-enrollment rules for a specific agency account, ordered by
  most recently inserted first.
  """
  @spec list_auto_enrollment_rules(integer()) :: list(AutoEnrollmentRule.t())
  def list_auto_enrollment_rules(agency_id) do
    from(r in AutoEnrollmentRule,
      where: r.agency_id == ^agency_id,
      order_by: [desc: r.inserted_at, desc: r.id]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new auto-enrollment rule for an agency account.

  Returns {:ok, rule} on success or {:error, changeset} on validation failure.
  """
  @spec create_auto_enrollment_rule(map()) ::
          {:ok, AutoEnrollmentRule.t()} | {:error, Ecto.Changeset.t()}
  def create_auto_enrollment_rule(attrs) do
    %AutoEnrollmentRule{}
    |> AutoEnrollmentRule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing auto-enrollment rule with new attributes.

  Returns {:ok, updated_rule} on success or {:error, changeset} on validation failure.
  """
  @spec update_auto_enrollment_rule(AutoEnrollmentRule.t(), map()) ::
          {:ok, AutoEnrollmentRule.t()} | {:error, Ecto.Changeset.t()}
  def update_auto_enrollment_rule(%AutoEnrollmentRule{} = rule, attrs) do
    rule
    |> AutoEnrollmentRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Finds an active auto-enrollment rule matching the given email domain.

  Performs a case-insensitive comparison. Returns the matching rule or nil
  when no enabled rule matches the domain.
  """
  @spec find_matching_rule(String.t()) :: AutoEnrollmentRule.t() | nil
  def find_matching_rule(email_domain) do
    downcased = String.downcase(email_domain)

    from(r in AutoEnrollmentRule,
      where: fragment("lower(?)", r.email_domain) == ^downcased and r.enabled == true
    )
    |> Repo.one()
  end

  @doc """
  Finds any auto-enrollment rule (enabled or disabled) matching the given
  email domain across all agencies.

  Used to enforce cross-agency domain uniqueness before inserting a new rule.
  Returns the matching rule or nil when no rule exists for the domain.
  """
  @spec find_any_rule_for_domain(String.t()) :: AutoEnrollmentRule.t() | nil
  def find_any_rule_for_domain(email_domain) do
    downcased = String.downcase(email_domain)

    from(r in AutoEnrollmentRule,
      where: fragment("lower(?)", r.email_domain) == ^downcased
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Team member operations
  # ---------------------------------------------------------------------------

  @doc """
  Lists all team members for an agency account with user associations preloaded.

  Returns members ordered by most recently added first.
  """
  @spec list_team_members(integer()) :: list(AccountMember.t())
  def list_team_members(account_id) do
    from(m in AccountMember,
      where: m.account_id == ^account_id,
      preload: [:user],
      order_by: [desc: m.inserted_at, desc: m.id]
    )
    |> Repo.all()
  end

  @doc """
  Adds a user to an agency team with the :member role by default.

  Returns {:ok, member} on success or {:error, changeset} on failure.
  """
  @spec add_team_member(integer(), integer()) ::
          {:ok, AccountMember.t()} | {:error, Ecto.Changeset.t()}
  def add_team_member(account_id, user_id) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account_id, user_id: user_id, role: :read_only})
    |> Repo.insert()
  end

  @doc """
  Removes a user from an agency team.

  Returns {:ok, deleted_member} on success or {:error, :not_found} when no
  membership exists for the given account_id and user_id pair.
  """
  @spec remove_team_member(integer(), integer()) ::
          {:ok, AccountMember.t()} | {:error, :not_found}
  def remove_team_member(account_id, user_id) do
    case Repo.get_by(AccountMember, account_id: account_id, user_id: user_id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  # ---------------------------------------------------------------------------
  # Client account access operations
  # ---------------------------------------------------------------------------

  @doc """
  Lists all client accounts that an agency has access to, ordered by most
  recently created grant first.
  """
  @spec list_client_accounts(integer()) :: list(AgencyClientAccessGrant.t())
  def list_client_accounts(agency_account_id) do
    from(g in AgencyClientAccessGrant,
      where: g.agency_account_id == ^agency_account_id,
      order_by: [desc: g.inserted_at, desc: g.id]
    )
    |> Repo.all()
  end

  @doc """
  Retrieves an agency's access grant for a specific client account.

  Returns the grant struct or nil when no grant exists.
  """
  @spec get_client_access(integer(), integer()) :: AgencyClientAccessGrant.t() | nil
  def get_client_access(agency_account_id, client_account_id) do
    Repo.get_by(AgencyClientAccessGrant,
      agency_account_id: agency_account_id,
      client_account_id: client_account_id
    )
  end

  @doc """
  Grants an agency access to a client account at the specified access level.

  Performs an upsert — if an access grant already exists for the
  (agency_account_id, client_account_id) pair, the access_level is updated.
  Returns {:ok, grant} on success or {:error, changeset} on failure.
  """
  @spec grant_client_access(integer(), integer(), atom()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, Ecto.Changeset.t()}
  def grant_client_access(agency_account_id, client_account_id, access_level) do
    attrs = %{
      agency_account_id: agency_account_id,
      client_account_id: client_account_id,
      access_level: access_level
    }

    changeset = AgencyClientAccessGrant.changeset(%AgencyClientAccessGrant{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:access_level, :updated_at]},
      conflict_target: [:agency_account_id, :client_account_id]
    )
  end

  @doc """
  Revokes an agency's access to a client account.

  Returns {:ok, deleted_grant} on success or {:error, :not_found} when no
  grant exists for the given pair.
  """
  @spec revoke_client_access(integer(), integer()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, :not_found}
  def revoke_client_access(agency_account_id, client_account_id) do
    case get_client_access(agency_account_id, client_account_id) do
      nil -> {:error, :not_found}
      grant -> Repo.delete(grant)
    end
  end

  @doc """
  Lists all agencies that have access to a specific client account.

  Orders results with originators first, then by most recently created grant.
  """
  @spec list_account_agencies(integer()) :: list(AgencyClientAccessGrant.t())
  def list_account_agencies(client_account_id) do
    from(g in AgencyClientAccessGrant,
      where: g.client_account_id == ^client_account_id,
      order_by: [
        asc:
          fragment(
            "CASE WHEN ? = 'originator' THEN 0 ELSE 1 END",
            g.origination_status
          ),
        asc: g.inserted_at,
        asc: g.id
      ]
    )
    |> Repo.all()
  end

  @doc """
  Finds the first agency access grant for a given client account where the
  agency_account_id is one of the provided user account IDs.

  Used by AccountLive.Index to display access level and origination status
  badges for client accounts accessed via an agency grant.

  Returns the grant struct or nil when no matching grant exists.
  """
  @spec find_grant_for_user_client_account(integer(), list(integer())) ::
          AgencyClientAccessGrant.t() | nil
  def find_grant_for_user_client_account(client_account_id, user_account_ids)
      when user_account_ids == [] do
    _ = client_account_id
    nil
  end

  def find_grant_for_user_client_account(client_account_id, user_account_ids) do
    from(g in AgencyClientAccessGrant,
      where:
        g.client_account_id == ^client_account_id and
          g.agency_account_id in ^user_account_ids,
      limit: 1
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Originator operations
  # ---------------------------------------------------------------------------

  @doc """
  Marks an agency as the originator of a client account.

  Returns {:ok, updated_grant} on success or {:error, reason} when the access
  grant does not exist.
  """
  @spec mark_as_originator(integer(), integer()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, term()}
  def mark_as_originator(agency_account_id, client_account_id) do
    case get_client_access(agency_account_id, client_account_id) do
      nil ->
        {:error, :not_found}

      grant ->
        grant
        |> AgencyClientAccessGrant.originator_changeset(%{origination_status: :originator})
        |> Repo.update()
    end
  end

  @doc """
  Returns true if a specific agency is marked as the originator of the given
  client account, false otherwise.
  """
  @spec originated_by?(integer(), integer()) :: boolean()
  def originated_by?(agency_account_id, client_account_id) do
    from(g in AgencyClientAccessGrant,
      where:
        g.agency_account_id == ^agency_account_id and
          g.client_account_id == ^client_account_id and
          g.origination_status == :originator
    )
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # WhiteLabelConfig operations
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves white-label configuration for an agency account.

  Returns the config struct or nil when no config exists.
  """
  @spec get_white_label_config(integer()) :: WhiteLabelConfig.t() | nil
  def get_white_label_config(agency_id) do
    Repo.get_by(WhiteLabelConfig, agency_id: agency_id)
  end

  @doc """
  Retrieves white-label configuration by subdomain.

  Returns the config struct or nil when no config matches the subdomain.
  """
  @spec get_white_label_config_by_subdomain(String.t()) :: WhiteLabelConfig.t() | nil
  def get_white_label_config_by_subdomain(subdomain) do
    Repo.get_by(WhiteLabelConfig, subdomain: subdomain)
  end

  @doc """
  Deletes white-label configuration for an agency.

  Returns `{number_deleted, nil}`. No-op if no config exists.
  """
  @spec delete_white_label_config(integer()) :: {non_neg_integer(), nil}
  def delete_white_label_config(agency_id) do
    from(c in WhiteLabelConfig, where: c.agency_id == ^agency_id)
    |> Repo.delete_all()
  end

  @doc """
  Creates or updates white-label configuration for an agency.

  Performs an upsert — if a config already exists for the agency_id, all
  fields except :id and :inserted_at are replaced. Returns {:ok, config} on
  success or {:error, changeset} on validation failure.
  """
  @spec upsert_white_label_config(integer(), map()) ::
          {:ok, WhiteLabelConfig.t()} | {:error, Ecto.Changeset.t()}
  def upsert_white_label_config(agency_id, attrs) do
    attrs_with_agency = Map.put(attrs, :agency_id, agency_id)

    %WhiteLabelConfig{}
    |> WhiteLabelConfig.changeset(attrs_with_agency)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:agency_id]
    )
  end
end
