defmodule MetricFlow.Agencies.AgenciesRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.AgenciesFixtures
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies.AgenciesRepository

  # ---------------------------------------------------------------------------
  # get_auto_enrollment_rule/1
  # ---------------------------------------------------------------------------

  describe "get_auto_enrollment_rule/1" do
    test "returns auto-enrollment rule when one exists for account" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id)

      result = AgenciesRepository.get_auto_enrollment_rule(agency.id)

      assert result.id == rule.id
      assert result.agency_id == agency.id
    end

    test "returns nil when no rule exists for account" do
      agency = account_fixture()

      result = AgenciesRepository.get_auto_enrollment_rule(agency.id)

      assert result == nil
    end

    test "returns nil when account_id doesn't match" do
      agency = account_fixture()
      auto_enrollment_rule_fixture(agency.id)

      other_agency = account_fixture()
      result = AgenciesRepository.get_auto_enrollment_rule(other_agency.id)

      assert result == nil
    end
  end

  # ---------------------------------------------------------------------------
  # create_auto_enrollment_rule/1
  # ---------------------------------------------------------------------------

  describe "create_auto_enrollment_rule/1" do
    test "creates rule with valid attributes" do
      agency = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(agency.id)

      assert {:ok, rule} = AgenciesRepository.create_auto_enrollment_rule(attrs)

      assert rule.agency_id == agency.id
      assert rule.email_domain == "example.com"
      assert rule.default_access_level == :read_only
      assert rule.enabled == true
    end

    test "returns error when domain is invalid format" do
      agency = account_fixture()

      attrs = %{
        agency_id: agency.id,
        email_domain: "not a valid domain!",
        default_access_level: :read_only,
        enabled: true
      }

      assert {:error, changeset} = AgenciesRepository.create_auto_enrollment_rule(attrs)
      refute changeset.valid?
      assert %{email_domain: [_]} = errors_on(changeset)
    end

    test "returns error when default_access_level is invalid" do
      agency = account_fixture()

      attrs = %{
        agency_id: agency.id,
        email_domain: "example.com",
        default_access_level: :superadmin,
        enabled: true
      }

      assert {:error, changeset} = AgenciesRepository.create_auto_enrollment_rule(attrs)
      refute changeset.valid?
      assert %{default_access_level: [_]} = errors_on(changeset)
    end

    test "returns error when account_id is missing" do
      attrs = %{
        email_domain: "example.com",
        default_access_level: :read_only,
        enabled: true
      }

      assert {:error, changeset} = AgenciesRepository.create_auto_enrollment_rule(attrs)
      refute changeset.valid?
      assert %{agency_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique constraint on domain" do
      agency = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(agency.id)

      assert {:ok, _first} = AgenciesRepository.create_auto_enrollment_rule(attrs)
      assert {:error, changeset} = AgenciesRepository.create_auto_enrollment_rule(attrs)
      refute changeset.valid?
      assert %{email_domain: ["has already been taken"]} = errors_on(changeset)
    end

    test "stores enabled flag" do
      agency = account_fixture()

      attrs = %{
        agency_id: agency.id,
        email_domain: "example.com",
        default_access_level: :admin,
        enabled: false
      }

      assert {:ok, rule} = AgenciesRepository.create_auto_enrollment_rule(attrs)
      assert rule.enabled == false
    end
  end

  # ---------------------------------------------------------------------------
  # update_auto_enrollment_rule/2
  # ---------------------------------------------------------------------------

  describe "update_auto_enrollment_rule/2" do
    test "updates rule with valid attributes" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id)

      assert {:ok, updated} =
               AgenciesRepository.update_auto_enrollment_rule(rule, %{
                 default_access_level: :admin
               })

      assert updated.id == rule.id
      assert updated.default_access_level == :admin
    end

    test "allows updating domain" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id)

      assert {:ok, updated} =
               AgenciesRepository.update_auto_enrollment_rule(rule, %{
                 email_domain: "updated-domain.com"
               })

      assert updated.email_domain == "updated-domain.com"
    end

    test "allows updating enabled flag" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id, %{enabled: true})

      assert {:ok, updated} =
               AgenciesRepository.update_auto_enrollment_rule(rule, %{enabled: false})

      assert updated.enabled == false
    end

    test "allows updating default_access_level" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id, %{default_access_level: :read_only})

      assert {:ok, updated} =
               AgenciesRepository.update_auto_enrollment_rule(rule, %{
                 default_access_level: :account_manager
               })

      assert updated.default_access_level == :account_manager
    end

    test "returns error with invalid attributes" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id)

      assert {:error, changeset} =
               AgenciesRepository.update_auto_enrollment_rule(rule, %{
                 email_domain: "BAD DOMAIN!!!"
               })

      refute changeset.valid?
      assert %{email_domain: [_]} = errors_on(changeset)
    end

    test "enforces unique constraint on domain" do
      agency = account_fixture()
      _rule_one = auto_enrollment_rule_fixture(agency.id, %{email_domain: "first.com"})
      rule_two = auto_enrollment_rule_fixture(agency.id, %{email_domain: "second.com"})

      assert {:error, changeset} =
               AgenciesRepository.update_auto_enrollment_rule(rule_two, %{
                 email_domain: "first.com"
               })

      refute changeset.valid?
      assert %{email_domain: ["has already been taken"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # list_auto_enrollment_rules/1
  # ---------------------------------------------------------------------------

  describe "list_auto_enrollment_rules/1" do
    test "returns all rules for specified account" do
      agency = account_fixture()
      rule_a = auto_enrollment_rule_fixture(agency.id, %{email_domain: "alpha.com"})
      rule_b = auto_enrollment_rule_fixture(agency.id, %{email_domain: "beta.com"})

      results = AgenciesRepository.list_auto_enrollment_rules(agency.id)
      result_ids = Enum.map(results, & &1.id)

      assert rule_a.id in result_ids
      assert rule_b.id in result_ids
    end

    test "returns empty list when no rules exist" do
      agency = account_fixture()

      assert AgenciesRepository.list_auto_enrollment_rules(agency.id) == []
    end

    test "does not return rules for other accounts" do
      agency = account_fixture()
      other_agency = account_fixture()

      auto_enrollment_rule_fixture(other_agency.id, %{email_domain: "other.com"})

      results = AgenciesRepository.list_auto_enrollment_rules(agency.id)

      assert results == []
    end

    test "orders by inserted_at descending" do
      agency = account_fixture()
      first = auto_enrollment_rule_fixture(agency.id, %{email_domain: "first.com"})
      second = auto_enrollment_rule_fixture(agency.id, %{email_domain: "second.com"})

      results = AgenciesRepository.list_auto_enrollment_rules(agency.id)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end
  end

  # ---------------------------------------------------------------------------
  # find_matching_rule/2
  # ---------------------------------------------------------------------------

  describe "find_matching_rule/2" do
    test "returns rule when domain matches and enabled is true" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id, %{email_domain: "match.com", enabled: true})

      result = AgenciesRepository.find_matching_rule("match.com")

      assert result.id == rule.id
    end

    test "returns nil when domain matches but enabled is false" do
      agency = account_fixture()
      auto_enrollment_rule_fixture(agency.id, %{email_domain: "disabled.com", enabled: false})

      result = AgenciesRepository.find_matching_rule("disabled.com")

      assert result == nil
    end

    test "returns nil when no rule matches domain" do
      result = AgenciesRepository.find_matching_rule("nonexistent.com")

      assert result == nil
    end

    test "case-insensitive domain matching" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id, %{email_domain: "casematch.com", enabled: true})

      result = AgenciesRepository.find_matching_rule("CASEMATCH.COM")

      assert result.id == rule.id
    end

    test "handles email addresses with subdomains correctly" do
      agency = account_fixture()
      rule = auto_enrollment_rule_fixture(agency.id, %{email_domain: "sub.example.com", enabled: true})

      result = AgenciesRepository.find_matching_rule("sub.example.com")

      assert result.id == rule.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_team_members/1
  # ---------------------------------------------------------------------------

  describe "list_team_members/1" do
    test "returns all team members for specified account" do
      agency = account_fixture()
      user_a = user_fixture()
      user_b = user_fixture()

      Repo.insert!(%AccountMember{account_id: agency.id, user_id: user_a.id, role: :admin})
      Repo.insert!(%AccountMember{account_id: agency.id, user_id: user_b.id, role: :read_only})

      results = AgenciesRepository.list_team_members(agency.id)
      result_user_ids = Enum.map(results, & &1.user_id)

      assert user_a.id in result_user_ids
      assert user_b.id in result_user_ids
    end

    test "preloads user associations" do
      agency = account_fixture()
      user = user_fixture()

      Repo.insert!(%AccountMember{account_id: agency.id, user_id: user.id, role: :admin})

      results = AgenciesRepository.list_team_members(agency.id)

      assert length(results) == 1
      assert Ecto.assoc_loaded?(hd(results).user)
      assert hd(results).user.id == user.id
    end

    test "returns empty list when no members exist" do
      agency = account_fixture()

      assert AgenciesRepository.list_team_members(agency.id) == []
    end

    test "orders by most recently added" do
      agency = account_fixture()
      user_first = user_fixture()
      user_second = user_fixture()

      first_member =
        Repo.insert!(%AccountMember{account_id: agency.id, user_id: user_first.id, role: :read_only})

      second_member =
        Repo.insert!(%AccountMember{account_id: agency.id, user_id: user_second.id, role: :admin})

      results = AgenciesRepository.list_team_members(agency.id)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second_member.id, first_member.id]
    end

    test "does not return members from other accounts" do
      agency = account_fixture()
      other_agency = account_fixture()
      other_user = user_fixture()

      Repo.insert!(%AccountMember{account_id: other_agency.id, user_id: other_user.id, role: :admin})

      results = AgenciesRepository.list_team_members(agency.id)

      assert results == []
    end
  end

  # ---------------------------------------------------------------------------
  # add_team_member/2
  # ---------------------------------------------------------------------------

  describe "add_team_member/2" do
    test "creates member with specified user_id and account_id" do
      agency = account_fixture()
      user = user_fixture()

      assert {:ok, member} = AgenciesRepository.add_team_member(agency.id, user.id)

      assert member.account_id == agency.id
      assert member.user_id == user.id
    end

    test "defaults to member role if not specified" do
      agency = account_fixture()
      user = user_fixture()

      assert {:ok, member} = AgenciesRepository.add_team_member(agency.id, user.id)

      assert member.role == :read_only
    end

    test "returns error for duplicate membership" do
      agency = account_fixture()
      user = user_fixture()

      Repo.insert!(%AccountMember{account_id: agency.id, user_id: user.id, role: :read_only})

      assert {:error, changeset} = AgenciesRepository.add_team_member(agency.id, user.id)
      refute changeset.valid?
    end

    test "validates user_id exists" do
      agency = account_fixture()
      nonexistent_user_id = -1

      assert {:error, _reason} = AgenciesRepository.add_team_member(agency.id, nonexistent_user_id)
    end

    test "validates account_id exists" do
      user = user_fixture()
      nonexistent_account_id = -1

      assert {:error, _reason} = AgenciesRepository.add_team_member(nonexistent_account_id, user.id)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_team_member/2
  # ---------------------------------------------------------------------------

  describe "remove_team_member/2" do
    test "deletes member when found" do
      agency = account_fixture()
      user = user_fixture()

      Repo.insert!(%AccountMember{account_id: agency.id, user_id: user.id, role: :read_only})

      assert {:ok, _deleted} = AgenciesRepository.remove_team_member(agency.id, user.id)

      assert Repo.get_by(AccountMember, account_id: agency.id, user_id: user.id) == nil
    end

    test "returns error when member not found" do
      agency = account_fixture()
      user = user_fixture()

      assert {:error, :not_found} = AgenciesRepository.remove_team_member(agency.id, user.id)
    end

    test "does not affect members of other accounts" do
      agency = account_fixture()
      other_agency = account_fixture()
      user = user_fixture()

      other_member =
        Repo.insert!(%AccountMember{
          account_id: other_agency.id,
          user_id: user.id,
          role: :read_only
        })

      assert {:error, :not_found} = AgenciesRepository.remove_team_member(agency.id, user.id)

      assert Repo.get(AccountMember, other_member.id) != nil
    end

    test "returns deleted member struct" do
      agency = account_fixture()
      user = user_fixture()

      inserted =
        Repo.insert!(%AccountMember{account_id: agency.id, user_id: user.id, role: :read_only})

      assert {:ok, deleted} = AgenciesRepository.remove_team_member(agency.id, user.id)
      assert deleted.id == inserted.id
      assert deleted.user_id == user.id
      assert deleted.account_id == agency.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_client_accounts/1
  # ---------------------------------------------------------------------------

  describe "list_client_accounts/1" do
    test "returns all client accounts agency has access to" do
      agency = account_fixture()
      client_a = account_fixture()
      client_b = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client_a.id, :read_only)
      AgenciesRepository.grant_client_access(agency.id, client_b.id, :account_manager)

      results = AgenciesRepository.list_client_accounts(agency.id)

      assert length(results) == 2
      client_ids = Enum.map(results, & &1.client_account_id)
      assert client_a.id in client_ids
      assert client_b.id in client_ids
    end

    test "includes access_level for each account" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :admin)

      results = AgenciesRepository.list_client_accounts(agency.id)

      assert length(results) == 1
      assert hd(results).access_level == :admin
    end

    test "includes origination_status (originator or invited)" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      results = AgenciesRepository.list_client_accounts(agency.id)

      assert length(results) == 1
      assert hd(results).origination_status in [:originator, :invited]
    end

    test "returns empty list when no access exists" do
      agency = account_fixture()

      assert AgenciesRepository.list_client_accounts(agency.id) == []
    end

    test "orders by most recently created" do
      agency = account_fixture()
      client_a = account_fixture()
      client_b = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client_a.id, :read_only)
      AgenciesRepository.grant_client_access(agency.id, client_b.id, :read_only)

      results = AgenciesRepository.list_client_accounts(agency.id)
      result_client_ids = Enum.map(results, & &1.client_account_id)

      assert result_client_ids == [client_b.id, client_a.id]
    end

    test "does not return accounts agency has no access to" do
      agency = account_fixture()
      _unrelated_client = account_fixture()

      assert AgenciesRepository.list_client_accounts(agency.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_client_access/2
  # ---------------------------------------------------------------------------

  describe "get_client_access/2" do
    test "returns access details when agency has access" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      result = AgenciesRepository.get_client_access(agency.id, client.id)

      assert result != nil
    end

    test "returns nil when agency has no access" do
      agency = account_fixture()
      client = account_fixture()

      result = AgenciesRepository.get_client_access(agency.id, client.id)

      assert result == nil
    end

    test "includes access_level" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :account_manager)

      result = AgenciesRepository.get_client_access(agency.id, client.id)

      assert result.access_level == :account_manager
    end

    test "includes origination_status" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      result = AgenciesRepository.get_client_access(agency.id, client.id)

      assert Map.has_key?(result, :origination_status)
    end
  end

  # ---------------------------------------------------------------------------
  # grant_client_access/3
  # ---------------------------------------------------------------------------

  describe "grant_client_access/3" do
    test "creates access grant with valid attributes" do
      agency = account_fixture()
      client = account_fixture()

      assert {:ok, grant} = AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      assert grant.agency_account_id == agency.id
      assert grant.client_account_id == client.id
      assert grant.access_level == :read_only
    end

    test "updates existing access grant when one exists" do
      agency = account_fixture()
      client = account_fixture()

      assert {:ok, _first} = AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)
      assert {:ok, updated} = AgenciesRepository.grant_client_access(agency.id, client.id, :admin)

      assert updated.access_level == :admin
    end

    test "returns error when access_level is invalid" do
      agency = account_fixture()
      client = account_fixture()

      assert {:error, changeset} =
               AgenciesRepository.grant_client_access(agency.id, client.id, :superadmin)

      refute changeset.valid?
    end

    test "validates agency_account_id exists" do
      client = account_fixture()

      assert {:error, _reason} =
               AgenciesRepository.grant_client_access(-1, client.id, :read_only)
    end

    test "validates client_account_id exists" do
      agency = account_fixture()

      assert {:error, _reason} =
               AgenciesRepository.grant_client_access(agency.id, -1, :read_only)
    end
  end

  # ---------------------------------------------------------------------------
  # revoke_client_access/2
  # ---------------------------------------------------------------------------

  describe "revoke_client_access/2" do
    test "deletes access grant when found" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      assert {:ok, _deleted} = AgenciesRepository.revoke_client_access(agency.id, client.id)

      assert AgenciesRepository.get_client_access(agency.id, client.id) == nil
    end

    test "returns error when access grant not found" do
      agency = account_fixture()
      client = account_fixture()

      assert {:error, :not_found} = AgenciesRepository.revoke_client_access(agency.id, client.id)
    end

    test "does not affect other access grants" do
      agency = account_fixture()
      client_a = account_fixture()
      client_b = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client_a.id, :read_only)
      AgenciesRepository.grant_client_access(agency.id, client_b.id, :read_only)

      assert {:ok, _deleted} = AgenciesRepository.revoke_client_access(agency.id, client_a.id)

      assert AgenciesRepository.get_client_access(agency.id, client_b.id) != nil
    end

    test "returns deleted access grant map" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      assert {:ok, deleted} = AgenciesRepository.revoke_client_access(agency.id, client.id)
      assert deleted.agency_account_id == agency.id
      assert deleted.client_account_id == client.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_account_agencies/1
  # ---------------------------------------------------------------------------

  describe "list_account_agencies/1" do
    test "returns all agencies with access to specified account" do
      agency_a = account_fixture()
      agency_b = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency_a.id, client.id, :read_only)
      AgenciesRepository.grant_client_access(agency_b.id, client.id, :account_manager)

      results = AgenciesRepository.list_account_agencies(client.id)

      assert length(results) == 2
      agency_ids = Enum.map(results, & &1.agency_account_id)
      assert agency_a.id in agency_ids
      assert agency_b.id in agency_ids
    end

    test "includes access_level for each agency" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :admin)

      results = AgenciesRepository.list_account_agencies(client.id)

      assert length(results) == 1
      assert hd(results).access_level == :admin
    end

    test "includes origination_status" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      results = AgenciesRepository.list_account_agencies(client.id)

      assert length(results) == 1
      assert Map.has_key?(hd(results), :origination_status)
    end

    test "orders by originator first, then by date" do
      agency_originator = account_fixture()
      agency_invited = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency_invited.id, client.id, :read_only)
      AgenciesRepository.grant_client_access(agency_originator.id, client.id, :read_only)
      AgenciesRepository.mark_as_originator(agency_originator.id, client.id)

      results = AgenciesRepository.list_account_agencies(client.id)
      first_result = hd(results)

      assert first_result.agency_account_id == agency_originator.id
      assert first_result.origination_status == :originator
    end

    test "returns empty list when no agencies have access" do
      client = account_fixture()

      assert AgenciesRepository.list_account_agencies(client.id) == []
    end

    test "does not return agencies without access" do
      agency_with_access = account_fixture()
      agency_without_access = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency_with_access.id, client.id, :read_only)

      results = AgenciesRepository.list_account_agencies(client.id)
      result_agency_ids = Enum.map(results, & &1.agency_account_id)

      assert agency_with_access.id in result_agency_ids
      refute agency_without_access.id in result_agency_ids
    end
  end

  # ---------------------------------------------------------------------------
  # get_white_label_config/1
  # ---------------------------------------------------------------------------

  describe "get_white_label_config/1" do
    test "returns white-label config when one exists" do
      agency = account_fixture()
      config = white_label_config_fixture(agency.id)

      result = AgenciesRepository.get_white_label_config(agency.id)

      assert result.id == config.id
      assert result.agency_id == agency.id
    end

    test "returns nil when no config exists" do
      agency = account_fixture()

      result = AgenciesRepository.get_white_label_config(agency.id)

      assert result == nil
    end

    test "returns nil when account_id doesn't match" do
      agency = account_fixture()
      white_label_config_fixture(agency.id)

      other_agency = account_fixture()
      result = AgenciesRepository.get_white_label_config(other_agency.id)

      assert result == nil
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_white_label_config/2
  # ---------------------------------------------------------------------------

  describe "upsert_white_label_config/2" do
    test "creates new config when none exists" do
      agency = account_fixture()
      attrs = valid_white_label_config_attrs(agency.id)

      assert {:ok, config} = AgenciesRepository.upsert_white_label_config(agency.id, attrs)

      assert config.agency_id == agency.id
      assert config.subdomain == attrs.subdomain
    end

    test "updates existing config when one exists" do
      agency = account_fixture()
      original_attrs = valid_white_label_config_attrs(agency.id)
      AgenciesRepository.upsert_white_label_config(agency.id, original_attrs)

      updated_attrs = Map.put(original_attrs, :primary_color, "#123456")

      assert {:ok, updated} = AgenciesRepository.upsert_white_label_config(agency.id, updated_attrs)

      assert updated.primary_color == "#123456"
      assert updated.subdomain == original_attrs.subdomain
    end

    test "validates hex color format" do
      agency = account_fixture()

      attrs =
        agency.id
        |> valid_white_label_config_attrs()
        |> Map.put(:primary_color, "not-a-hex")

      assert {:error, changeset} = AgenciesRepository.upsert_white_label_config(agency.id, attrs)
      refute changeset.valid?
      assert %{primary_color: [_]} = errors_on(changeset)
    end

    test "validates subdomain format" do
      agency = account_fixture()

      attrs =
        agency.id
        |> valid_white_label_config_attrs()
        |> Map.put(:subdomain, "INVALID SUBDOMAIN!!!")

      assert {:error, changeset} = AgenciesRepository.upsert_white_label_config(agency.id, attrs)
      refute changeset.valid?
      assert %{subdomain: [_]} = errors_on(changeset)
    end

    test "enforces unique subdomain constraint" do
      agency_a = account_fixture()
      agency_b = account_fixture()

      attrs_a = valid_white_label_config_attrs(agency_a.id)
      AgenciesRepository.upsert_white_label_config(agency_a.id, attrs_a)

      attrs_b = Map.put(valid_white_label_config_attrs(agency_b.id), :subdomain, attrs_a.subdomain)

      assert {:error, changeset} = AgenciesRepository.upsert_white_label_config(agency_b.id, attrs_b)
      refute changeset.valid?
      assert %{subdomain: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows nil values for optional fields" do
      agency = account_fixture()
      unique = System.unique_integer([:positive])

      attrs = %{
        subdomain: "agency-#{unique}",
        logo_url: nil,
        primary_color: nil,
        secondary_color: nil,
        custom_css: nil
      }

      assert {:ok, config} = AgenciesRepository.upsert_white_label_config(agency.id, attrs)
      assert config.logo_url == nil
      assert config.primary_color == nil
      assert config.secondary_color == nil
    end
  end

  # ---------------------------------------------------------------------------
  # mark_as_originator/2
  # ---------------------------------------------------------------------------

  describe "mark_as_originator/2" do
    test "updates origination_status to originator when access exists" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      assert {:ok, updated} = AgenciesRepository.mark_as_originator(agency.id, client.id)
      assert updated.origination_status == :originator
    end

    test "returns error when access grant not found" do
      agency = account_fixture()
      client = account_fixture()

      assert {:error, _reason} = AgenciesRepository.mark_as_originator(agency.id, client.id)
    end

    test "does not affect other access grants" do
      agency = account_fixture()
      client_a = account_fixture()
      client_b = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client_a.id, :read_only)
      AgenciesRepository.grant_client_access(agency.id, client_b.id, :read_only)

      AgenciesRepository.mark_as_originator(agency.id, client_a.id)

      grant_b = AgenciesRepository.get_client_access(agency.id, client_b.id)
      assert grant_b.origination_status != :originator
    end

    test "returns updated access grant map" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      assert {:ok, grant} = AgenciesRepository.mark_as_originator(agency.id, client.id)
      assert grant.agency_account_id == agency.id
      assert grant.client_account_id == client.id
      assert grant.origination_status == :originator
    end
  end

  # ---------------------------------------------------------------------------
  # originated_by?/2
  # ---------------------------------------------------------------------------

  describe "originated_by?/2" do
    test "returns true when agency is marked as originator" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)
      AgenciesRepository.mark_as_originator(agency.id, client.id)

      assert AgenciesRepository.originated_by?(agency.id, client.id) == true
    end

    test "returns false when agency is not originator" do
      agency = account_fixture()
      client = account_fixture()

      AgenciesRepository.grant_client_access(agency.id, client.id, :read_only)

      assert AgenciesRepository.originated_by?(agency.id, client.id) == false
    end

    test "returns false when agency has no access" do
      agency = account_fixture()
      client = account_fixture()

      assert AgenciesRepository.originated_by?(agency.id, client.id) == false
    end

    test "returns false when access grant doesn't exist" do
      assert AgenciesRepository.originated_by?(-1, -1) == false
    end
  end
end
