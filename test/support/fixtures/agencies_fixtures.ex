defmodule MetricFlowTest.AgenciesFixtures do
  @moduledoc """
  Test helpers for creating entities in the Agencies domain.

  AutoEnrollmentRule requires an agency_id that references accounts.id.
  Use `account_fixture/0` to create a persisted account backed by a real user,
  then pass its id as the agency_id when building auto enrollment rule attributes.

  WhiteLabelConfig requires an agency_id and a unique subdomain.
  Use `white_label_config_fixture/1` with an account's id to create a persisted config.

  For access grant tests, use `agency_client_access_grant_fixture/3` to create a
  persisted AgencyClientAccessGrant for a given agency and client account pair.
  """

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies.AgencyClientAccessGrant
  alias MetricFlow.Agencies.AutoEnrollmentRule
  alias MetricFlow.Agencies.WhiteLabelConfig
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Account / Agency fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Creates and persists an Account record to use as an agency or client.
  Creates a backing user to satisfy the originator_user_id foreign key.
  Returns the inserted Account struct.
  """
  def account_fixture(attrs \\ %{}) do
    user = user_fixture()
    unique = System.unique_integer([:positive])

    defaults = %{
      name: "Agency Account #{unique}",
      slug: "agency-account-#{unique}",
      type: "team",
      originator_user_id: user.id
    }

    merged = Map.merge(defaults, Map.new(attrs))

    %Account{}
    |> Account.creation_changeset(merged)
    |> Repo.insert!()
  end

  @doc """
  Creates a persisted Account with an AccountMember record linking the given user
  to the account with the specified role. Returns the account struct.
  """
  def account_with_member_fixture(user, role \\ :member) do
    account = account_fixture()

    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()

    account
  end

  # ---------------------------------------------------------------------------
  # AutoEnrollmentRule fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for AutoEnrollmentRule.changeset/2.
  Requires an integer agency_id (the id of a persisted Account).
  """
  def valid_auto_enrollment_rule_attrs(agency_id) do
    %{
      agency_id: agency_id,
      email_domain: "example.com",
      default_access_level: :read_only,
      enabled: true
    }
  end

  @doc """
  Creates and persists an AutoEnrollmentRule for the given agency_id.
  Accepts optional attribute overrides.
  """
  def auto_enrollment_rule_fixture(agency_id, attrs \\ %{}) do
    defaults = valid_auto_enrollment_rule_attrs(agency_id)
    merged = Map.merge(defaults, Map.new(attrs))

    %AutoEnrollmentRule{}
    |> AutoEnrollmentRule.changeset(merged)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # WhiteLabelConfig fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for WhiteLabelConfig.changeset/2.
  Requires an integer agency_id (the id of a persisted Account).
  Generates a unique subdomain to avoid conflicts between tests.
  """
  def valid_white_label_config_attrs(agency_id) do
    unique = System.unique_integer([:positive])

    %{
      agency_id: agency_id,
      subdomain: "agency-#{unique}",
      logo_url: "https://example.com/logo.png",
      primary_color: "#FF5733",
      secondary_color: "#3498DB",
      custom_css: nil
    }
  end

  @doc """
  Creates and persists a WhiteLabelConfig for the given agency_id.
  Accepts optional attribute overrides.
  """
  def white_label_config_fixture(agency_id, attrs \\ %{}) do
    defaults = valid_white_label_config_attrs(agency_id)
    merged = Map.merge(defaults, Map.new(attrs))

    %WhiteLabelConfig{}
    |> WhiteLabelConfig.changeset(merged)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # AgencyClientAccessGrant fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for AgencyClientAccessGrant.changeset/2.
  Requires integer agency_account_id and client_account_id (ids of persisted Accounts).
  """
  def valid_agency_client_access_grant_attrs(agency_account_id, client_account_id) do
    %{
      agency_account_id: agency_account_id,
      client_account_id: client_account_id,
      access_level: :read_only,
      origination_status: :invited
    }
  end

  @doc """
  Creates and persists an AgencyClientAccessGrant for the given agency and client accounts.
  Accepts optional attribute overrides.
  """
  def agency_client_access_grant_fixture(agency_account_id, client_account_id, attrs \\ %{}) do
    defaults = valid_agency_client_access_grant_attrs(agency_account_id, client_account_id)
    merged = Map.merge(defaults, Map.new(attrs))

    %AgencyClientAccessGrant{}
    |> AgencyClientAccessGrant.changeset(merged)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Convenience helpers for white-label BDD specs
  # ---------------------------------------------------------------------------

  @doc """
  Creates an agency account with white-label branding configuration.
  Accepts a map with :subdomain, :logo_url, :primary_color, :secondary_color.
  Returns the agency Account struct.
  """
  def agency_with_white_label_fixture(white_label_attrs \\ %{}) do
    agency = account_fixture(%{type: "team"})

    white_label_config_fixture(agency.id, white_label_attrs)

    agency
  end

  @doc """
  Grants an agency originator-level access to a client account.
  Creates an AgencyClientAccessGrant with origination_status: :originator.
  """
  def grant_agency_originator_access(agency_id, client_account_id) do
    agency_client_access_grant_fixture(agency_id, client_account_id, %{
      access_level: :admin,
      origination_status: :originator
    })
  end
end
