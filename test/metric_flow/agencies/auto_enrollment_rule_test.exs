defmodule MetricFlow.Agencies.AutoEnrollmentRuleTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Agencies.AutoEnrollmentRule
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp new_rule do
    struct!(AutoEnrollmentRule, [])
  end

  defp insert_rule!(attrs) do
    new_rule()
    |> AutoEnrollmentRule.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      account = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(account.id)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
    end

    test "casts agency_id correctly" do
      account = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(account.id)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert get_change(changeset, :agency_id) == account.id
    end

    test "casts email_domain correctly" do
      account = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(account.id)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert get_change(changeset, :email_domain) == "example.com"
    end

    test "casts default_access_level correctly" do
      account = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(account.id)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert get_change(changeset, :default_access_level) == :read_only
    end

    test "casts enabled correctly" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :enabled, false)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert get_change(changeset, :enabled) == false
    end

    test "validates agency_id is required" do
      account = account_fixture()
      attrs = Map.delete(valid_auto_enrollment_rule_attrs(account.id), :agency_id)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      refute changeset.valid?
      assert %{agency_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email_domain is required" do
      account = account_fixture()
      attrs = Map.delete(valid_auto_enrollment_rule_attrs(account.id), :email_domain)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      refute changeset.valid?
      assert %{email_domain: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates default_access_level is required" do
      account = account_fixture()
      attrs = Map.delete(valid_auto_enrollment_rule_attrs(account.id), :default_access_level)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      refute changeset.valid?
      assert %{default_access_level: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows enabled to default to true when not provided" do
      account = account_fixture()
      attrs = Map.delete(valid_auto_enrollment_rule_attrs(account.id), :enabled)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
    end

    test "validates email_domain format is valid (e.g., \"example.com\")" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "example.com")

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
    end

    test "rejects email_domain with invalid characters (e.g., spaces, @ symbols)" do
      account = account_fixture()

      attrs_with_space =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "bad domain.com")

      changeset_space = AutoEnrollmentRule.changeset(new_rule(), attrs_with_space)

      refute changeset_space.valid?
      assert %{email_domain: [_]} = errors_on(changeset_space)

      attrs_with_at =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "@example.com")

      changeset_at = AutoEnrollmentRule.changeset(new_rule(), attrs_with_at)

      refute changeset_at.valid?
      assert %{email_domain: [_]} = errors_on(changeset_at)
    end

    test "rejects email_domain with uppercase letters" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "Example.com")

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      refute changeset.valid?
      assert %{email_domain: [_]} = errors_on(changeset)
    end

    test "accepts email_domain with subdomains (e.g., \"mail.example.com\")" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "mail.example.com")

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
    end

    test "accepts email_domain with hyphens (e.g., \"my-company.com\")" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "my-company.com")

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
    end

    test "validates default_access_level is one of allowed enum values" do
      account = account_fixture()

      for level <- [:read_only, :account_manager, :admin] do
        attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :default_access_level, level)
        changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

        assert changeset.valid?, "expected #{level} to be a valid default_access_level"
      end
    end

    test "rejects invalid default_access_level values (e.g., :owner, :member)" do
      account = account_fixture()

      attrs_owner =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :default_access_level, :owner)

      changeset_owner = AutoEnrollmentRule.changeset(new_rule(), attrs_owner)

      refute changeset_owner.valid?
      assert %{default_access_level: [_]} = errors_on(changeset_owner)

      attrs_member =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :default_access_level, :member)

      changeset_member = AutoEnrollmentRule.changeset(new_rule(), attrs_member)

      refute changeset_member.valid?
      assert %{default_access_level: [_]} = errors_on(changeset_member)
    end

    test "accepts :read_only as default_access_level" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :default_access_level, :read_only)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :default_access_level) == :read_only
    end

    test "accepts :account_manager as default_access_level" do
      account = account_fixture()

      attrs =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :default_access_level, :account_manager)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :default_access_level) == :account_manager
    end

    test "accepts :admin as default_access_level" do
      account = account_fixture()
      attrs = Map.put(valid_auto_enrollment_rule_attrs(account.id), :default_access_level, :admin)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :default_access_level) == :admin
    end

    test "validates agency association exists (assoc_constraint triggers on insert)" do
      attrs = valid_auto_enrollment_rule_attrs(-1)

      {:error, changeset} =
        new_rule()
        |> AutoEnrollmentRule.changeset(attrs)
        |> Repo.insert()

      assert %{agency: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces unique constraint on agency_id and email_domain combination" do
      account = account_fixture()
      attrs = valid_auto_enrollment_rule_attrs(account.id)

      _first = insert_rule!(attrs)

      {:error, changeset} =
        new_rule()
        |> AutoEnrollmentRule.changeset(attrs)
        |> Repo.insert()

      assert %{email_domain: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same email_domain for different agencies" do
      account_one = account_fixture()
      account_two = account_fixture()

      attrs_one = valid_auto_enrollment_rule_attrs(account_one.id)
      attrs_two = valid_auto_enrollment_rule_attrs(account_two.id)

      _rule_one = insert_rule!(attrs_one)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs_two)

      assert changeset.valid?
    end

    test "allows different email_domains for same agency" do
      account = account_fixture()

      attrs_first =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "first.com")

      attrs_second =
        Map.put(valid_auto_enrollment_rule_attrs(account.id), :email_domain, "second.com")

      _rule_first = insert_rule!(attrs_first)

      changeset = AutoEnrollmentRule.changeset(new_rule(), attrs_second)

      assert changeset.valid?
    end

    test "creates valid changeset for updating existing rule" do
      account = account_fixture()
      rule = insert_rule!(valid_auto_enrollment_rule_attrs(account.id))

      update_attrs = %{default_access_level: :admin}
      changeset = AutoEnrollmentRule.changeset(rule, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :default_access_level) == :admin
    end

    test "preserves existing fields when updating subset of attributes" do
      account = account_fixture()
      rule = insert_rule!(valid_auto_enrollment_rule_attrs(account.id))

      update_attrs = %{default_access_level: :account_manager}
      changeset = AutoEnrollmentRule.changeset(rule, update_attrs)

      assert changeset.data.agency_id == account.id
      assert changeset.data.email_domain == "example.com"
      assert changeset.data.enabled == true
    end

    test "allows disabling rule by setting enabled to false" do
      account = account_fixture()
      rule = insert_rule!(valid_auto_enrollment_rule_attrs(account.id))

      update_attrs = %{enabled: false}
      changeset = AutoEnrollmentRule.changeset(rule, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :enabled) == false
    end

    test "allows re-enabling rule by setting enabled to true" do
      account = account_fixture()

      rule =
        insert_rule!(
          Map.put(valid_auto_enrollment_rule_attrs(account.id), :enabled, false)
        )

      update_attrs = %{enabled: true}
      changeset = AutoEnrollmentRule.changeset(rule, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :enabled) == true
    end

    test "handles empty attributes map gracefully" do
      account = account_fixture()
      rule = insert_rule!(valid_auto_enrollment_rule_attrs(account.id))

      changeset = AutoEnrollmentRule.changeset(rule, %{})

      assert changeset.valid?
    end
  end
end
