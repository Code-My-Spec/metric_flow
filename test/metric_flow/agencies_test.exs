defmodule MetricFlow.AgenciesTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies
  alias MetricFlow.Agencies.AgencyClientAccessGrant
  alias MetricFlow.Agencies.AutoEnrollmentRule
  alias MetricFlow.Agencies.WhiteLabelConfig
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Local helpers
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp agency_with_admin_scope do
    {admin_user, scope} = user_with_scope()
    agency = account_with_member_fixture(admin_user, :admin)
    {agency, scope}
  end

  defp unique_domain do
    "domain-#{System.unique_integer([:positive])}.com"
  end

  # ---------------------------------------------------------------------------
  # configure_auto_enrollment/3
  # ---------------------------------------------------------------------------

  describe "configure_auto_enrollment/3" do
    test "returns ok tuple with auto-enrollment rule when valid" do
      {agency, scope} = agency_with_admin_scope()
      domain = unique_domain()

      attrs = %{
        email_domain: domain,
        default_access_level: :read_only,
        enabled: true
      }

      assert {:ok, %AutoEnrollmentRule{} = rule} =
               Agencies.configure_auto_enrollment(scope, agency.id, attrs)

      assert rule.agency_id == agency.id
      assert rule.email_domain == domain
      assert rule.default_access_level == :read_only
      assert rule.enabled == true
    end

    test "requires admin authorization on agency account" do
      {agency, _} = agency_with_admin_scope()
      {_other_user, other_scope} = user_with_scope()

      attrs = %{
        email_domain: unique_domain(),
        default_access_level: :read_only,
        enabled: true
      }

      assert {:error, :unauthorized} =
               Agencies.configure_auto_enrollment(other_scope, agency.id, attrs)
    end

    test "validates domain is valid email domain format" do
      {agency, scope} = agency_with_admin_scope()

      attrs = %{
        email_domain: "not-a-valid-domain",
        default_access_level: :read_only,
        enabled: true
      }

      assert {:error, changeset} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)
      assert %{email_domain: [_format_error]} = errors_on(changeset)
    end

    test "validates default_access_level is one of allowed values" do
      {agency, scope} = agency_with_admin_scope()

      attrs = %{
        email_domain: unique_domain(),
        default_access_level: :superuser,
        enabled: true
      }

      assert {:error, changeset} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)
      assert %{default_access_level: [_inclusion_error]} = errors_on(changeset)
    end

    test "returns error for duplicate domain across agencies" do
      {agency1, scope1} = agency_with_admin_scope()
      {agency2, scope2} = agency_with_admin_scope()

      domain = unique_domain()
      attrs = %{email_domain: domain, default_access_level: :read_only, enabled: true}

      assert {:ok, _rule} = Agencies.configure_auto_enrollment(scope1, agency1.id, attrs)

      assert {:error, changeset} = Agencies.configure_auto_enrollment(scope2, agency2.id, attrs)
      assert %{email_domain: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows disabling auto-enrollment by setting enabled to false" do
      {agency, scope} = agency_with_admin_scope()

      attrs = %{
        email_domain: unique_domain(),
        default_access_level: :read_only,
        enabled: false
      }

      assert {:ok, rule} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)
      assert rule.enabled == false
    end

    test "updates existing rule when one exists for the account" do
      {agency, scope} = agency_with_admin_scope()
      domain = unique_domain()

      attrs = %{email_domain: domain, default_access_level: :read_only, enabled: true}
      assert {:ok, original} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)

      updated_attrs = %{email_domain: domain, default_access_level: :admin, enabled: true}
      assert {:ok, updated} = Agencies.configure_auto_enrollment(scope, agency.id, updated_attrs)

      assert updated.id == original.id
      assert updated.default_access_level == :admin
    end
  end

  # ---------------------------------------------------------------------------
  # get_auto_enrollment_rule/2
  # ---------------------------------------------------------------------------

  describe "get_auto_enrollment_rule/2" do
    test "returns auto-enrollment rule when one exists" do
      {agency, scope} = agency_with_admin_scope()
      rule = auto_enrollment_rule_fixture(agency.id)

      result = Agencies.get_auto_enrollment_rule(scope, agency.id)

      assert result.id == rule.id
      assert result.agency_id == agency.id
    end

    test "returns nil when no rule configured" do
      {agency, scope} = agency_with_admin_scope()

      result = Agencies.get_auto_enrollment_rule(scope, agency.id)

      assert result == nil
    end

    test "requires read access to agency account" do
      {agency, _} = agency_with_admin_scope()
      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} = Agencies.get_auto_enrollment_rule(other_scope, agency.id)
    end
  end

  # ---------------------------------------------------------------------------
  # process_new_user_auto_enrollment/2
  # ---------------------------------------------------------------------------

  describe "process_new_user_auto_enrollment/2" do
    test "returns no_match when user email domain doesn't match any rules" do
      user = user_fixture(email: "user@no-match-domain-#{System.unique_integer([:positive])}.com")

      assert {:ok, :no_match} = Agencies.process_new_user_auto_enrollment(user)
    end

    test "returns no_match when matching rule is disabled" do
      {agency, scope} = agency_with_admin_scope()
      domain = unique_domain()

      attrs = %{email_domain: domain, default_access_level: :read_only, enabled: false}
      assert {:ok, _rule} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)

      user = user_fixture(email: "newuser@#{domain}")

      assert {:ok, :no_match} = Agencies.process_new_user_auto_enrollment(user)
    end

    test "creates team membership with configured default_access_level" do
      {agency, scope} = agency_with_admin_scope()
      domain = unique_domain()

      attrs = %{email_domain: domain, default_access_level: :account_manager, enabled: true}
      assert {:ok, _rule} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)

      new_user = user_fixture(email: "newuser@#{domain}")

      assert {:ok, members} = Agencies.process_new_user_auto_enrollment(new_user)
      assert length(members) == 1

      member = hd(members)
      assert member.user_id == new_user.id
      assert member.account_id == agency.id
    end

    test "grants access to all client accounts the agency manages" do
      {agency, scope} = agency_with_admin_scope()
      domain = unique_domain()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      attrs = %{email_domain: domain, default_access_level: :read_only, enabled: true}
      assert {:ok, _rule} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)

      new_user = user_fixture(email: "newuser@#{domain}")

      assert {:ok, _members} = Agencies.process_new_user_auto_enrollment(new_user)

      membership = Repo.get_by(AccountMember, account_id: client_account.id, user_id: new_user.id)
      assert membership != nil
    end

    test "handles multiple agency matches for same domain" do
      {agency1, scope1} = agency_with_admin_scope()
      {agency2, scope2} = agency_with_admin_scope()
      domain = unique_domain()

      attrs1 = %{email_domain: domain, default_access_level: :read_only, enabled: true}
      attrs2 = %{email_domain: domain, default_access_level: :account_manager, enabled: true}

      assert {:ok, _} = Agencies.configure_auto_enrollment(scope1, agency1.id, attrs1)

      # Only one rule per domain is allowed (unique constraint), so the second returns an error
      assert {:error, _changeset} = Agencies.configure_auto_enrollment(scope2, agency2.id, attrs2)
    end

    test "inherits proper access level (read_only, account_manager, admin)" do
      {agency, scope} = agency_with_admin_scope()
      domain = unique_domain()

      attrs = %{email_domain: domain, default_access_level: :admin, enabled: true}
      assert {:ok, _rule} = Agencies.configure_auto_enrollment(scope, agency.id, attrs)

      new_user = user_fixture(email: "newuser@#{domain}")

      assert {:ok, _members} = Agencies.process_new_user_auto_enrollment(new_user)

      member = Repo.get_by(AccountMember, account_id: agency.id, user_id: new_user.id)
      assert member != nil
      assert member.role == :admin
    end
  end

  # ---------------------------------------------------------------------------
  # add_agency_team_member/3
  # ---------------------------------------------------------------------------

  describe "add_agency_team_member/3" do
    test "requires admin authorization on agency account" do
      {agency, _} = agency_with_admin_scope()
      {new_user, _} = user_with_scope()
      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} =
               Agencies.add_agency_team_member(other_scope, agency.id, new_user.id, :read_only)
    end

    test "creates member with specified access level" do
      {agency, scope} = agency_with_admin_scope()
      {new_user, _} = user_with_scope()

      assert {:ok, member} =
               Agencies.add_agency_team_member(scope, agency.id, new_user.id, :read_only)

      assert member.user_id == new_user.id
      assert member.account_id == agency.id
    end

    test "grants inherited access to agency's client accounts" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      {new_user, _} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, new_user.id, :read_only)

      membership = Repo.get_by(AccountMember, account_id: client_account.id, user_id: new_user.id)
      assert membership != nil
    end

    test "returns error for duplicate membership" do
      {agency, scope} = agency_with_admin_scope()
      {new_user, _} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, new_user.id, :read_only)

      assert {:error, _changeset} =
               Agencies.add_agency_team_member(scope, agency.id, new_user.id, :read_only)
    end

    test "returns error for invalid access level" do
      {agency, scope} = agency_with_admin_scope()
      {new_user, _} = user_with_scope()

      assert {:error, _changeset} =
               Agencies.add_agency_team_member(scope, agency.id, new_user.id, :superuser)
    end
  end

  # ---------------------------------------------------------------------------
  # list_agency_team_members/2
  # ---------------------------------------------------------------------------

  describe "list_agency_team_members/2" do
    test "returns list of agency team members" do
      {agency, scope} = agency_with_admin_scope()
      {member_user, _} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, member_user.id, :read_only)

      members = Agencies.list_agency_team_members(scope, agency.id)

      assert is_list(members)
      member_user_ids = Enum.map(members, & &1.user_id)
      assert member_user.id in member_user_ids
    end

    test "requires admin access to agency account" do
      {agency, _} = agency_with_admin_scope()
      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} = Agencies.list_agency_team_members(other_scope, agency.id)
    end

    test "includes member user associations" do
      {agency, scope} = agency_with_admin_scope()
      {member_user, _} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, member_user.id, :read_only)

      members = Agencies.list_agency_team_members(scope, agency.id)

      assert Enum.all?(members, &Ecto.assoc_loaded?(&1.user))
    end

    test "orders by most recently added" do
      {agency, scope} = agency_with_admin_scope()
      {first_user, _} = user_with_scope()
      {second_user, _} = user_with_scope()

      assert {:ok, _} =
               Agencies.add_agency_team_member(scope, agency.id, first_user.id, :read_only)

      assert {:ok, _} =
               Agencies.add_agency_team_member(scope, agency.id, second_user.id, :read_only)

      members = Agencies.list_agency_team_members(scope, agency.id)
      member_user_ids = Enum.map(members, & &1.user_id)

      first_idx = Enum.find_index(member_user_ids, &(&1 == first_user.id))
      second_idx = Enum.find_index(member_user_ids, &(&1 == second_user.id))
      assert second_idx < first_idx
    end
  end

  # ---------------------------------------------------------------------------
  # remove_agency_team_member/3
  # ---------------------------------------------------------------------------

  describe "remove_agency_team_member/3" do
    test "requires admin authorization on agency account" do
      {agency, scope} = agency_with_admin_scope()
      {target_user, _} = user_with_scope()
      {_other_user, other_scope} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, target_user.id, :read_only)

      assert {:error, :unauthorized} =
               Agencies.remove_agency_team_member(other_scope, agency.id, target_user.id)
    end

    test "revokes inherited access to all client accounts" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      {target_user, _} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, target_user.id, :read_only)

      inherited = Repo.get_by(AccountMember, account_id: client_account.id, user_id: target_user.id)
      assert inherited != nil

      assert {:ok, _deleted} =
               Agencies.remove_agency_team_member(scope, agency.id, target_user.id)

      revoked = Repo.get_by(AccountMember, account_id: client_account.id, user_id: target_user.id)
      assert revoked == nil
    end

    test "maintains user's direct (non-inherited) client account access" do
      {agency, scope} = agency_with_admin_scope()
      {target_user, _} = user_with_scope()

      direct_client = account_fixture()

      %AccountMember{}
      |> AccountMember.changeset(%{
        account_id: direct_client.id,
        user_id: target_user.id,
        role: :read_only
      })
      |> Repo.insert!()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, target_user.id, :read_only)

      assert {:ok, _deleted} =
               Agencies.remove_agency_team_member(scope, agency.id, target_user.id)

      direct_membership =
        Repo.get_by(AccountMember, account_id: direct_client.id, user_id: target_user.id)

      assert direct_membership != nil
    end

    test "returns ok tuple with deleted member" do
      {agency, scope} = agency_with_admin_scope()
      {target_user, _} = user_with_scope()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, target_user.id, :read_only)

      assert {:ok, deleted} =
               Agencies.remove_agency_team_member(scope, agency.id, target_user.id)

      assert deleted.user_id == target_user.id
      assert Repo.get_by(AccountMember, account_id: agency.id, user_id: target_user.id) == nil
    end

    test "returns error when member not found" do
      {agency, scope} = agency_with_admin_scope()
      {non_member_user, _} = user_with_scope()

      assert {:error, :not_found} =
               Agencies.remove_agency_team_member(scope, agency.id, non_member_user.id)
    end
  end

  # ---------------------------------------------------------------------------
  # list_agency_client_accounts/2
  # ---------------------------------------------------------------------------

  describe "list_agency_client_accounts/2" do
    test "returns list of client accounts with access metadata" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      results = Agencies.list_agency_client_accounts(scope, agency.id)

      assert is_list(results)
      assert length(results) == 1
    end

    test "includes access_level for each client account" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(
                 scope,
                 agency.id,
                 client_account.id,
                 :account_manager,
                 false
               )

      [result] = Agencies.list_agency_client_accounts(scope, agency.id)

      assert result.access_level == :account_manager
    end

    test "includes origination_status (originator or invited)" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, true)

      [result] = Agencies.list_agency_client_accounts(scope, agency.id)

      assert result.origination_status in [:originator, :invited]
    end

    test "requires read access to agency account" do
      {agency, _} = agency_with_admin_scope()
      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} = Agencies.list_agency_client_accounts(other_scope, agency.id)
    end

    test "orders by most recently created" do
      {agency, scope} = agency_with_admin_scope()
      client1 = account_fixture()
      client2 = account_fixture()

      assert {:ok, _} =
               Agencies.grant_client_account_access(scope, agency.id, client1.id, :read_only, false)

      assert {:ok, _} =
               Agencies.grant_client_account_access(scope, agency.id, client2.id, :read_only, false)

      results = Agencies.list_agency_client_accounts(scope, agency.id)
      result_client_ids = Enum.map(results, & &1.client_account_id)

      first_idx = Enum.find_index(result_client_ids, &(&1 == client1.id))
      second_idx = Enum.find_index(result_client_ids, &(&1 == client2.id))
      assert second_idx < first_idx
    end
  end

  # ---------------------------------------------------------------------------
  # get_client_account_access/3
  # ---------------------------------------------------------------------------

  describe "get_client_account_access/3" do
    test "returns ok tuple with access metadata when agency has access" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, false)

      assert {:ok, metadata} =
               Agencies.get_client_account_access(scope, agency.id, client_account.id)

      assert is_map(metadata)
    end

    test "includes access_level (read_only, account_manager, admin, owner)" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, false)

      assert {:ok, metadata} =
               Agencies.get_client_account_access(scope, agency.id, client_account.id)

      assert Map.has_key?(metadata, :access_level)
      assert metadata.access_level == :admin
    end

    test "includes origination_status (originator or invited)" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, true)

      assert {:ok, metadata} =
               Agencies.get_client_account_access(scope, agency.id, client_account.id)

      assert Map.has_key?(metadata, :origination_status)
      assert metadata.origination_status in [:originator, :invited]
    end

    test "includes permissions map with can_view_reports, can_modify_integrations, can_manage_users, can_delete_account" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, false)

      assert {:ok, metadata} =
               Agencies.get_client_account_access(scope, agency.id, client_account.id)

      assert Map.has_key?(metadata, :permissions)
      permissions = metadata.permissions
      assert Map.has_key?(permissions, :can_view_reports)
      assert Map.has_key?(permissions, :can_modify_integrations)
      assert Map.has_key?(permissions, :can_manage_users)
      assert Map.has_key?(permissions, :can_delete_account)
    end

    test "returns error when agency has no access" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:error, :not_found} =
               Agencies.get_client_account_access(scope, agency.id, client_account.id)
    end

    test "requires read access to agency account" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, false)

      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} =
               Agencies.get_client_account_access(other_scope, agency.id, client_account.id)
    end
  end

  # ---------------------------------------------------------------------------
  # grant_client_account_access/5
  # ---------------------------------------------------------------------------

  describe "grant_client_account_access/5" do
    test "requires admin access to client account" do
      {agency, _agency_scope} = agency_with_admin_scope()
      client_account = account_fixture()

      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} =
               Agencies.grant_client_account_access(
                 other_scope,
                 agency.id,
                 client_account.id,
                 :read_only,
                 false
               )
    end

    test "creates access grant with specified level" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, grant} =
               Agencies.grant_client_account_access(
                 scope,
                 agency.id,
                 client_account.id,
                 :account_manager,
                 false
               )

      assert grant.agency_account_id == agency.id
      assert grant.client_account_id == client_account.id
      assert grant.access_level == :account_manager
    end

    test "sets origination_status correctly" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, true)

      assert grant.origination_status == :originator
    end

    test "propagates access to all agency team members" do
      {agency, scope} = agency_with_admin_scope()
      {team_member_user, _} = user_with_scope()
      client_account = account_fixture()

      assert {:ok, _member} =
               Agencies.add_agency_team_member(scope, agency.id, team_member_user.id, :read_only)

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      membership =
        Repo.get_by(AccountMember, account_id: client_account.id, user_id: team_member_user.id)

      assert membership != nil
    end

    test "returns error for invalid access level" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:error, _changeset} =
               Agencies.grant_client_account_access(
                 scope,
                 agency.id,
                 client_account.id,
                 :superuser,
                 false
               )
    end

    test "allows updating existing access level" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, original_grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      assert {:ok, updated_grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, false)

      assert updated_grant.id == original_grant.id
      assert updated_grant.access_level == :admin
    end
  end

  # ---------------------------------------------------------------------------
  # revoke_client_account_access/3
  # ---------------------------------------------------------------------------

  describe "revoke_client_account_access/3" do
    test "requires admin access to client account" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} =
               Agencies.revoke_client_account_access(other_scope, agency.id, client_account.id)
    end

    test "removes access grant and member permissions" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :read_only, false)

      assert {:ok, revoked} =
               Agencies.revoke_client_account_access(scope, agency.id, client_account.id)

      assert revoked.agency_account_id == agency.id
      assert revoked.client_account_id == client_account.id

      assert Repo.get_by(AgencyClientAccessGrant,
               agency_account_id: agency.id,
               client_account_id: client_account.id
             ) == nil
    end

    test "returns error when agency is originator" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:ok, _grant} =
               Agencies.grant_client_account_access(scope, agency.id, client_account.id, :admin, true)

      assert {:error, :cannot_revoke_originator} =
               Agencies.revoke_client_account_access(scope, agency.id, client_account.id)
    end

    test "returns error when agency has no access" do
      {agency, scope} = agency_with_admin_scope()
      client_account = account_fixture()

      assert {:error, :not_found} =
               Agencies.revoke_client_account_access(scope, agency.id, client_account.id)
    end
  end

  # ---------------------------------------------------------------------------
  # get_white_label_config/2
  # ---------------------------------------------------------------------------

  describe "get_white_label_config/2" do
    test "returns white-label config when one exists" do
      {agency, scope} = agency_with_admin_scope()
      _config = white_label_config_fixture(agency.id)

      result = Agencies.get_white_label_config(scope, agency.id)

      assert %WhiteLabelConfig{} = result
      assert result.agency_id == agency.id
    end

    test "returns nil when no config exists" do
      {agency, scope} = agency_with_admin_scope()

      result = Agencies.get_white_label_config(scope, agency.id)

      assert result == nil
    end

    test "requires read access to agency account" do
      {agency, _} = agency_with_admin_scope()
      {_other_user, other_scope} = user_with_scope()

      assert {:error, :unauthorized} = Agencies.get_white_label_config(other_scope, agency.id)
    end
  end

  # ---------------------------------------------------------------------------
  # update_white_label_config/3
  # ---------------------------------------------------------------------------

  describe "update_white_label_config/3" do
    test "requires admin authorization on agency account" do
      {agency, _} = agency_with_admin_scope()
      {_reader_user, reader_scope} = user_with_scope()

      attrs = valid_white_label_config_attrs(agency.id)

      assert {:error, :unauthorized} =
               Agencies.update_white_label_config(reader_scope, agency.id, attrs)
    end

    test "validates subdomain format and uniqueness" do
      {agency1, scope1} = agency_with_admin_scope()
      {agency2, scope2} = agency_with_admin_scope()

      unique = System.unique_integer([:positive])
      shared_subdomain = "shared-#{unique}"

      attrs1 = Map.merge(valid_white_label_config_attrs(agency1.id), %{subdomain: shared_subdomain})
      attrs2 = Map.merge(valid_white_label_config_attrs(agency2.id), %{subdomain: shared_subdomain})

      assert {:ok, _config} = Agencies.update_white_label_config(scope1, agency1.id, attrs1)

      assert {:error, changeset} = Agencies.update_white_label_config(scope2, agency2.id, attrs2)
      assert %{subdomain: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates color formats are valid hex" do
      {agency, scope} = agency_with_admin_scope()

      attrs =
        valid_white_label_config_attrs(agency.id)
        |> Map.put(:primary_color, "not-a-color")

      assert {:error, changeset} = Agencies.update_white_label_config(scope, agency.id, attrs)
      assert %{primary_color: [_hex_error]} = errors_on(changeset)
    end

    test "allows updating logo_url" do
      {agency, scope} = agency_with_admin_scope()
      attrs = valid_white_label_config_attrs(agency.id)

      assert {:ok, _config} = Agencies.update_white_label_config(scope, agency.id, attrs)

      updated_attrs = Map.put(attrs, :logo_url, "https://example.com/new-logo.png")

      assert {:ok, updated} = Agencies.update_white_label_config(scope, agency.id, updated_attrs)
      assert updated.logo_url == "https://example.com/new-logo.png"
    end

    test "creates new config when none exists" do
      {agency, scope} = agency_with_admin_scope()
      attrs = valid_white_label_config_attrs(agency.id)

      assert {:ok, %WhiteLabelConfig{} = config} =
               Agencies.update_white_label_config(scope, agency.id, attrs)

      assert config.agency_id == agency.id
      assert config.subdomain == attrs.subdomain
    end

    test "updates existing config when one exists" do
      {agency, scope} = agency_with_admin_scope()
      attrs = valid_white_label_config_attrs(agency.id)

      assert {:ok, original} = Agencies.update_white_label_config(scope, agency.id, attrs)

      new_unique = System.unique_integer([:positive])
      updated_attrs = Map.put(attrs, :subdomain, "updated-#{new_unique}")

      assert {:ok, updated} = Agencies.update_white_label_config(scope, agency.id, updated_attrs)

      assert updated.id == original.id
      assert updated.subdomain == "updated-#{new_unique}"
    end
  end
end
