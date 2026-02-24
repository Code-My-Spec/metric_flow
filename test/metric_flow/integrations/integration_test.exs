defmodule MetricFlow.Integrations.IntegrationTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  defp past_expires_at do
    DateTime.add(DateTime.utc_now(), -3600, :second)
  end

  defp valid_attrs(user_id) do
    %{
      user_id: user_id,
      provider: :google,
      access_token: "access-token-value",
      refresh_token: "refresh-token-value",
      expires_at: future_expires_at(),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "12345"}
    }
  end

  defp new_integration do
    struct!(Integration, [])
  end

  defp insert_integration!(attrs) do
    new_integration()
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Integration.changeset(new_integration(), attrs)

      assert changeset.valid?
    end

    test "casts each field attribute correctly (user_id, provider, access_token, refresh_token, expires_at, granted_scopes, provider_metadata)" do
      user = user_fixture()
      expires_at = future_expires_at()
      attrs = %{valid_attrs(user.id) | expires_at: expires_at}

      changeset = Integration.changeset(new_integration(), attrs)

      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :provider) == :google
      assert get_change(changeset, :access_token) == "access-token-value"
      assert get_change(changeset, :refresh_token) == "refresh-token-value"
      assert get_change(changeset, :expires_at) == expires_at
      assert get_change(changeset, :granted_scopes) == ["email", "profile"]
      assert get_change(changeset, :provider_metadata) == %{"provider_user_id" => "12345"}
    end

    test "validates user_id is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :user_id)

      changeset = Integration.changeset(new_integration(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates provider is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :provider)

      changeset = Integration.changeset(new_integration(), attrs)

      refute changeset.valid?
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates access_token is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :access_token)

      changeset = Integration.changeset(new_integration(), attrs)

      refute changeset.valid?
      assert %{access_token: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates expires_at is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :expires_at)

      changeset = Integration.changeset(new_integration(), attrs)

      refute changeset.valid?
      assert %{expires_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows nil refresh_token as optional" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | refresh_token: nil}

      changeset = Integration.changeset(new_integration(), attrs)

      assert changeset.valid?
    end

    test "allows empty granted_scopes array" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | granted_scopes: []}

      changeset = Integration.changeset(new_integration(), attrs)

      assert changeset.valid?
    end

    test "allows nil granted_scopes (defaults to empty list)" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :granted_scopes)

      changeset = Integration.changeset(new_integration(), attrs)

      assert changeset.valid?
    end

    test "validates provider_metadata is a map" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | provider_metadata: %{"key" => "value"}}

      changeset = Integration.changeset(new_integration(), attrs)

      assert changeset.valid?
    end

    test "rejects provider_metadata when not a map" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | provider_metadata: "not-a-map"}

      changeset = Integration.changeset(new_integration(), attrs)

      refute changeset.valid?
      assert %{provider_metadata: [_]} = errors_on(changeset)
    end

    test "rejects provider_metadata when it is a list" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | provider_metadata: ["item1", "item2"]}

      changeset = Integration.changeset(new_integration(), attrs)

      refute changeset.valid?
      assert %{provider_metadata: [_]} = errors_on(changeset)
    end

    test "allows nil provider_metadata (defaults to empty map)" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :provider_metadata)

      changeset = Integration.changeset(new_integration(), attrs)

      assert changeset.valid?
    end

    test "accepts all valid provider enum values (:github, :gitlab, :bitbucket, :google, :google_ads, :facebook_ads, :google_analytics, :quickbooks)" do
      user = user_fixture()

      for provider <- [:github, :gitlab, :bitbucket, :google, :google_ads, :facebook_ads, :google_analytics, :quickbooks] do
        attrs = %{valid_attrs(user.id) | provider: provider}
        changeset = Integration.changeset(new_integration(), attrs)

        assert changeset.valid?, "expected #{provider} to be valid"
        assert get_change(changeset, :provider) == provider
      end
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_integration()
        |> Integration.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces unique constraint on user_id and provider combination" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      _first = insert_integration!(attrs)

      {:error, changeset} =
        new_integration()
        |> Integration.changeset(attrs)
        |> Repo.insert()

      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same provider for different users" do
      user_one = user_fixture()
      user_two = user_fixture()

      attrs_one = valid_attrs(user_one.id)
      attrs_two = valid_attrs(user_two.id)

      _integration_one = insert_integration!(attrs_one)

      changeset = Integration.changeset(new_integration(), attrs_two)

      assert changeset.valid?
    end

    test "allows different providers for same user" do
      user = user_fixture()

      attrs_google = %{valid_attrs(user.id) | provider: :google}
      attrs_github = %{valid_attrs(user.id) | provider: :github}

      _integration_google = insert_integration!(attrs_google)

      changeset = Integration.changeset(new_integration(), attrs_github)

      assert changeset.valid?
    end

    test "creates valid changeset for updating existing integration" do
      user = user_fixture()
      integration = insert_integration!(valid_attrs(user.id))

      new_token = "updated-access-token"
      update_attrs = %{access_token: new_token}

      changeset = Integration.changeset(integration, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :access_token) == new_token
    end

    test "preserves existing fields when updating subset of attributes" do
      user = user_fixture()
      integration = insert_integration!(valid_attrs(user.id))

      update_attrs = %{access_token: "new-token"}
      changeset = Integration.changeset(integration, update_attrs)

      assert changeset.data.provider == :google
      assert changeset.data.user_id == user.id
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      integration = insert_integration!(valid_attrs(user.id))

      changeset = Integration.changeset(integration, %{})

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # expired?/1
  # ---------------------------------------------------------------------------

  describe "expired?/1" do
    test "returns true when expires_at is in the past" do
      integration = struct!(Integration, expires_at: past_expires_at())

      assert Integration.expired?(integration)
    end

    test "returns false when expires_at is in the future" do
      integration = struct!(Integration, expires_at: future_expires_at())

      refute Integration.expired?(integration)
    end

    test "returns true when expires_at is exactly current time" do
      now = DateTime.utc_now()
      integration = struct!(Integration, expires_at: now)

      assert Integration.expired?(integration)
    end

    test "returns true when token expired one second ago" do
      one_second_ago = DateTime.add(DateTime.utc_now(), -1, :second)
      integration = struct!(Integration, expires_at: one_second_ago)

      assert Integration.expired?(integration)
    end

    test "returns false when token expires in one second" do
      in_one_second = DateTime.add(DateTime.utc_now(), 1, :second)
      integration = struct!(Integration, expires_at: in_one_second)

      refute Integration.expired?(integration)
    end

    test "returns false when token expires in one hour" do
      in_one_hour = DateTime.add(DateTime.utc_now(), 3600, :second)
      integration = struct!(Integration, expires_at: in_one_hour)

      refute Integration.expired?(integration)
    end

    test "returns true when token expired one hour ago" do
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
      integration = struct!(Integration, expires_at: one_hour_ago)

      assert Integration.expired?(integration)
    end

    test "compares against current UTC time" do
      future = DateTime.add(DateTime.utc_now(), 60, :second)
      integration = struct!(Integration, expires_at: future)

      refute Integration.expired?(integration)
    end

    test "works with integrations that have refresh tokens" do
      integration =
        struct!(Integration,
          expires_at: past_expires_at(),
          refresh_token: "some-refresh-token"
        )

      assert Integration.expired?(integration)
    end

    test "works with integrations without refresh tokens" do
      integration =
        struct!(Integration,
          expires_at: past_expires_at(),
          refresh_token: nil
        )

      assert Integration.expired?(integration)
    end
  end

  # ---------------------------------------------------------------------------
  # has_refresh_token?/1
  # ---------------------------------------------------------------------------

  describe "has_refresh_token?/1" do
    test "returns true when refresh_token is present" do
      integration = struct!(Integration, refresh_token: "some-refresh-token")

      assert Integration.has_refresh_token?(integration)
    end

    test "returns false when refresh_token is nil" do
      integration = struct!(Integration, refresh_token: nil)

      refute Integration.has_refresh_token?(integration)
    end

    test "returns true for expired integration with refresh_token" do
      integration =
        struct!(Integration,
          expires_at: past_expires_at(),
          refresh_token: "some-refresh-token"
        )

      assert Integration.has_refresh_token?(integration)
    end

    test "returns false for expired integration without refresh_token" do
      integration =
        struct!(Integration,
          expires_at: past_expires_at(),
          refresh_token: nil
        )

      refute Integration.has_refresh_token?(integration)
    end

    test "returns false when refresh_token is an empty string (implementation-dependent on encryption behavior)" do
      integration = struct!(Integration, refresh_token: "")

      refute Integration.has_refresh_token?(integration)
    end

    test "works with different providers" do
      integration_github =
        struct!(Integration,
          provider: :github,
          refresh_token: "github-refresh-token"
        )

      integration_google =
        struct!(Integration,
          provider: :google,
          refresh_token: nil
        )

      assert Integration.has_refresh_token?(integration_github)
      refute Integration.has_refresh_token?(integration_google)
    end

    test "works with provider that does not issue refresh tokens" do
      integration =
        struct!(Integration,
          provider: :google_analytics,
          refresh_token: nil
        )

      refute Integration.has_refresh_token?(integration)
    end
  end
end
