defmodule MetricFlow.Integrations.IntegrationRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Integrations.{Integration, IntegrationRepository}
  alias MetricFlow.Infrastructure.Repo

  describe "get_integration/2" do
    test "returns integration when it exists for scoped user and provider" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      assert {:ok, fetched} = IntegrationRepository.get_integration(scope, :github)
      assert fetched.id == integration.id
      assert fetched.provider == :github
      assert fetched.user_id == scope.user.id
    end

    test "returns error when integration doesn't exist for provider" do
      scope = user_scope_fixture()

      assert {:error, :not_found} = IntegrationRepository.get_integration(scope, :github)
    end

    test "returns error when integration exists for different user" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _integration = github_integration_fixture(scope1.user)

      assert {:error, :not_found} = IntegrationRepository.get_integration(scope2, :github)
    end

    test "decrypts access_token and refresh_token when loading" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      assert {:ok, fetched} = IntegrationRepository.get_integration(scope, :github)
      assert fetched.access_token == integration.access_token
      assert fetched.refresh_token == integration.refresh_token
    end

    test "enforces multi-tenant isolation" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      integration1 = github_integration_fixture(scope1.user)
      integration2 = github_integration_fixture(scope2.user)

      assert {:ok, result1} = IntegrationRepository.get_integration(scope1, :github)
      assert {:ok, result2} = IntegrationRepository.get_integration(scope2, :github)

      assert result1.id == integration1.id
      assert result2.id == integration2.id
      assert result1.id != result2.id
    end
  end

  describe "list_integrations/1" do
    test "returns all integrations for scoped user" do
      scope = user_scope_fixture()

      github = github_integration_fixture(scope.user)
      gitlab = gitlab_integration_fixture(scope.user)
      bitbucket = bitbucket_integration_fixture(scope.user)

      integrations = IntegrationRepository.list_integrations(scope)

      assert length(integrations) == 3
      integration_ids = Enum.map(integrations, & &1.id)
      assert github.id in integration_ids
      assert gitlab.id in integration_ids
      assert bitbucket.id in integration_ids
    end

    test "returns empty list when no integrations exist" do
      scope = user_scope_fixture()

      integrations = IntegrationRepository.list_integrations(scope)

      assert integrations == []
    end

    test "only returns integrations for scoped user" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      integration1 = github_integration_fixture(scope1.user)
      _integration2 = github_integration_fixture(scope2.user)

      integrations = IntegrationRepository.list_integrations(scope1)

      assert length(integrations) == 1
      assert List.first(integrations).id == integration1.id
    end

    test "orders by most recently created" do
      scope = user_scope_fixture()

      first = github_integration_fixture(scope.user)
      second = gitlab_integration_fixture(scope.user)
      third = bitbucket_integration_fixture(scope.user)

      integrations = IntegrationRepository.list_integrations(scope)

      assert Enum.map(integrations, & &1.id) == [third.id, second.id, first.id]
    end

    test "enforces multi-tenant isolation" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _integration1a = github_integration_fixture(scope1.user)
      _integration1b = gitlab_integration_fixture(scope1.user)
      _integration2 = github_integration_fixture(scope2.user)

      integrations1 = IntegrationRepository.list_integrations(scope1)
      integrations2 = IntegrationRepository.list_integrations(scope2)

      assert length(integrations1) == 2
      assert length(integrations2) == 1

      assert Enum.all?(integrations1, &(&1.user_id == scope1.user.id))
      assert Enum.all?(integrations2, &(&1.user_id == scope2.user.id))
    end
  end

  describe "create_integration/2" do
    test "creates integration with valid attributes" do
      scope = user_scope_fixture()
      attrs = valid_github_integration_attributes(scope.user)

      assert {:ok, %Integration{} = integration} =
               IntegrationRepository.create_integration(scope, attrs)

      assert integration.provider == :github
      assert integration.user_id == scope.user.id
      assert integration.access_token != nil
      assert integration.refresh_token != nil
      assert integration.expires_at != nil
    end

    test "returns error with invalid provider" do
      scope = user_scope_fixture()
      attrs = valid_integration_attributes(scope.user, %{provider: :invalid})

      assert {:error, changeset} = IntegrationRepository.create_integration(scope, attrs)
      assert %{provider: ["is invalid"]} = errors_on(changeset)
    end

    test "returns error with missing required fields" do
      scope = user_scope_fixture()
      attrs = %{provider: :github}

      assert {:error, changeset} = IntegrationRepository.create_integration(scope, attrs)
      errors = errors_on(changeset)
      assert %{access_token: ["can't be blank"]} = errors
      assert %{expires_at: ["can't be blank"]} = errors
    end

    test "returns error with duplicate user_id and provider" do
      scope = user_scope_fixture()
      attrs = valid_github_integration_attributes(scope.user)

      assert {:ok, _integration} = IntegrationRepository.create_integration(scope, attrs)
      assert {:error, changeset} = IntegrationRepository.create_integration(scope, attrs)
      assert %{user_id: ["already exists for this user"]} = errors_on(changeset)
    end

    test "allows same provider for different users" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      attrs1 = valid_github_integration_attributes(scope1.user)
      attrs2 = valid_github_integration_attributes(scope2.user)

      assert {:ok, integration1} = IntegrationRepository.create_integration(scope1, attrs1)
      assert {:ok, integration2} = IntegrationRepository.create_integration(scope2, attrs2)

      assert integration1.provider == integration2.provider
      assert integration1.user_id != integration2.user_id
    end

    test "stores granted_scopes and provider_metadata" do
      scope = user_scope_fixture()
      attrs = valid_github_integration_attributes(scope.user)

      assert {:ok, integration} = IntegrationRepository.create_integration(scope, attrs)
      assert integration.granted_scopes == attrs.granted_scopes
      assert integration.provider_metadata == attrs.provider_metadata
    end

    test "handles integration without refresh_token" do
      scope = user_scope_fixture()
      attrs = integration_without_refresh_token_attributes(scope.user)

      assert {:ok, integration} = IntegrationRepository.create_integration(scope, attrs)
      assert integration.refresh_token == nil
      assert integration.access_token != nil
    end
  end

  describe "update_integration/3" do
    test "updates integration with valid attributes" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      new_token = "new_access_token_#{System.unique_integer([:positive])}"
      new_expires_at = DateTime.utc_now() |> DateTime.add(7200, :second)
      attrs = %{access_token: new_token, expires_at: new_expires_at}

      assert {:ok, updated} = IntegrationRepository.update_integration(scope, :github, attrs)
      assert updated.id == integration.id
      assert updated.access_token == new_token
      assert updated.expires_at == new_expires_at
    end

    test "returns error when integration doesn't exist for scoped user" do
      scope = user_scope_fixture()
      attrs = %{access_token: "new_token"}

      assert {:error, :not_found} =
               IntegrationRepository.update_integration(scope, :github, attrs)
    end

    test "returns error when integration exists for different user" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _integration = github_integration_fixture(scope1.user)
      attrs = %{access_token: "new_token"}

      assert {:error, :not_found} =
               IntegrationRepository.update_integration(scope2, :github, attrs)
    end

    test "returns error with invalid attributes" do
      scope = user_scope_fixture()
      _integration = github_integration_fixture(scope.user)

      attrs = %{provider: :invalid}

      assert {:error, changeset} = IntegrationRepository.update_integration(scope, :github, attrs)
      assert %{provider: ["is invalid"]} = errors_on(changeset)
    end

    test "commonly used for token refresh operations" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      # Simulate token refresh
      new_access = "refreshed_token_#{System.unique_integer([:positive])}"
      new_expires = DateTime.utc_now() |> DateTime.add(3600, :second)
      attrs = %{access_token: new_access, expires_at: new_expires}

      assert {:ok, updated} = IntegrationRepository.update_integration(scope, :github, attrs)
      assert updated.access_token == new_access
      assert updated.expires_at == new_expires
      assert updated.provider == integration.provider
    end
  end

  describe "delete_integration/2" do
    test "deletes integration for scoped user and provider" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      assert {:ok, deleted} = IntegrationRepository.delete_integration(scope, :github)
      assert deleted.id == integration.id

      assert {:error, :not_found} = IntegrationRepository.get_integration(scope, :github)
    end

    test "returns error when integration doesn't exist" do
      scope = user_scope_fixture()

      assert {:error, :not_found} = IntegrationRepository.delete_integration(scope, :github)
    end

    test "returns error when integration exists for different user" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _integration = github_integration_fixture(scope1.user)

      assert {:error, :not_found} = IntegrationRepository.delete_integration(scope2, :github)
    end

    test "removes all associated encrypted tokens" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      assert {:ok, _deleted} = IntegrationRepository.delete_integration(scope, :github)

      # Verify integration is completely removed from database
      assert Repo.get(Integration, integration.id) == nil
    end

    test "does not affect integrations for other providers" do
      scope = user_scope_fixture()

      github = github_integration_fixture(scope.user)
      gitlab = gitlab_integration_fixture(scope.user)

      assert {:ok, deleted} = IntegrationRepository.delete_integration(scope, :github)
      assert deleted.id == github.id

      # Verify gitlab integration still exists
      assert {:ok, fetched} = IntegrationRepository.get_integration(scope, :gitlab)
      assert fetched.id == gitlab.id
    end
  end

  describe "by_provider/2" do
    test "returns integration for scoped user and provider" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      assert {:ok, fetched} = IntegrationRepository.by_provider(scope, :github)
      assert fetched.id == integration.id
    end

    test "is alias for get_integration/2" do
      scope = user_scope_fixture()
      integration = github_integration_fixture(scope.user)

      result1 = IntegrationRepository.get_integration(scope, :github)
      result2 = IntegrationRepository.by_provider(scope, :github)

      assert result1 == result2
      assert {:ok, fetched} = result2
      assert fetched.id == integration.id
    end

    test "provides semantic clarity when querying by provider" do
      scope = user_scope_fixture()
      _integration = gitlab_integration_fixture(scope.user)

      # Demonstrates semantic intent of the function
      assert {:ok, %Integration{provider: :gitlab}} =
               IntegrationRepository.by_provider(scope, :gitlab)
    end
  end

  describe "with_expired_tokens/1" do
    test "returns integrations where expires_at is less than current timestamp" do
      scope = user_scope_fixture()

      expired1 = expired_integration_fixture(scope.user, %{provider: :github})
      expired2 = expired_integration_fixture(scope.user, %{provider: :gitlab})
      _active = github_integration_fixture(scope.user, %{provider: :bitbucket})

      expired_integrations = IntegrationRepository.with_expired_tokens(scope)

      assert length(expired_integrations) == 2
      expired_ids = Enum.map(expired_integrations, & &1.id)
      assert expired1.id in expired_ids
      assert expired2.id in expired_ids
    end

    test "returns empty list when no integrations are expired" do
      scope = user_scope_fixture()

      _active1 = github_integration_fixture(scope.user)
      _active2 = gitlab_integration_fixture(scope.user)

      expired_integrations = IntegrationRepository.with_expired_tokens(scope)

      assert expired_integrations == []
    end

    test "only returns expired integrations for scoped user" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      expired1 = expired_integration_fixture(scope1.user)
      _expired2 = expired_integration_fixture(scope2.user)

      expired_integrations = IntegrationRepository.with_expired_tokens(scope1)

      assert length(expired_integrations) == 1
      assert List.first(expired_integrations).id == expired1.id
    end

    test "used to identify integrations requiring token refresh" do
      scope = user_scope_fixture()

      expired = expired_integration_fixture(scope.user)
      _active = github_integration_fixture(scope.user, %{provider: :gitlab})

      expired_integrations = IntegrationRepository.with_expired_tokens(scope)

      assert length(expired_integrations) == 1
      [integration] = expired_integrations
      assert integration.id == expired.id
      assert Integration.expired?(integration)
    end

    test "does not decrypt tokens when checking expiration" do
      scope = user_scope_fixture()
      expired = expired_integration_fixture(scope.user)

      expired_integrations = IntegrationRepository.with_expired_tokens(scope)

      assert length(expired_integrations) == 1
      [integration] = expired_integrations

      # expires_at is unencrypted and accessible
      assert integration.expires_at != nil
      assert integration.id == expired.id
    end

    test "enforces multi-tenant isolation" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      expired1 = expired_integration_fixture(scope1.user, %{provider: :github})
      expired2 = expired_integration_fixture(scope1.user, %{provider: :gitlab})
      _expired3 = expired_integration_fixture(scope2.user, %{provider: :github})

      expired_integrations1 = IntegrationRepository.with_expired_tokens(scope1)
      expired_integrations2 = IntegrationRepository.with_expired_tokens(scope2)

      assert length(expired_integrations1) == 2
      assert length(expired_integrations2) == 1

      assert Enum.all?(expired_integrations1, &(&1.user_id == scope1.user.id))
      assert Enum.all?(expired_integrations2, &(&1.user_id == scope2.user.id))

      expired_ids1 = Enum.map(expired_integrations1, & &1.id)
      assert expired1.id in expired_ids1
      assert expired2.id in expired_ids1
    end
  end

  describe "upsert_integration/3" do
    test "creates new integration when none exists" do
      scope = user_scope_fixture()
      attrs = valid_github_integration_attributes(scope.user)

      assert {:ok, integration} = IntegrationRepository.upsert_integration(scope, :github, attrs)
      assert integration.provider == :github
      assert integration.user_id == scope.user.id
      assert integration.access_token == attrs.access_token
    end

    test "updates existing integration when one exists" do
      scope = user_scope_fixture()
      existing = github_integration_fixture(scope.user)

      new_token = "new_token_#{System.unique_integer([:positive])}"
      attrs = valid_github_integration_attributes(scope.user, %{access_token: new_token})

      assert {:ok, integration} = IntegrationRepository.upsert_integration(scope, :github, attrs)
      assert integration.id == existing.id
      assert integration.access_token == new_token
    end

    test "based on unique constraint (user_id, provider)" do
      scope = user_scope_fixture()

      attrs1 = valid_github_integration_attributes(scope.user, %{access_token: "token1"})
      attrs2 = valid_github_integration_attributes(scope.user, %{access_token: "token2"})

      assert {:ok, integration1} =
               IntegrationRepository.upsert_integration(scope, :github, attrs1)

      assert {:ok, integration2} =
               IntegrationRepository.upsert_integration(scope, :github, attrs2)

      # Same integration was updated, not duplicated
      assert integration1.id == integration2.id
      assert integration2.access_token == "token2"

      # Verify only one integration exists
      integrations = IntegrationRepository.list_integrations(scope)
      assert length(integrations) == 1
    end

    test "used during OAuth callback for first-time connections" do
      scope = user_scope_fixture()
      attrs = valid_github_integration_attributes(scope.user)

      # Simulates OAuth callback creating new integration
      assert {:ok, integration} = IntegrationRepository.upsert_integration(scope, :github, attrs)
      assert integration.provider == :github
      assert integration.granted_scopes == attrs.granted_scopes
      assert integration.provider_metadata == attrs.provider_metadata
    end

    test "used during OAuth callback for reconnections" do
      scope = user_scope_fixture()
      existing = github_integration_fixture(scope.user)

      # Simulates OAuth callback reconnecting existing integration
      new_attrs =
        valid_github_integration_attributes(scope.user, %{
          access_token: "reconnected_token",
          granted_scopes: ["repo", "user:email", "admin:org"]
        })

      assert {:ok, integration} =
               IntegrationRepository.upsert_integration(scope, :github, new_attrs)

      assert integration.id == existing.id
      assert integration.access_token == "reconnected_token"
      assert integration.granted_scopes == ["repo", "user:email", "admin:org"]
    end

    test "returns error with invalid attributes" do
      scope = user_scope_fixture()
      attrs = %{provider: :github}

      assert {:error, changeset} = IntegrationRepository.upsert_integration(scope, :github, attrs)
      assert %{access_token: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows different providers for same user" do
      scope = user_scope_fixture()

      github_attrs = valid_github_integration_attributes(scope.user)
      gitlab_attrs = valid_gitlab_integration_attributes(scope.user)

      assert {:ok, github} =
               IntegrationRepository.upsert_integration(scope, :github, github_attrs)

      assert {:ok, gitlab} =
               IntegrationRepository.upsert_integration(scope, :gitlab, gitlab_attrs)

      assert github.id != gitlab.id
      assert github.provider == :github
      assert gitlab.provider == :gitlab

      integrations = IntegrationRepository.list_integrations(scope)
      assert length(integrations) == 2
    end
  end

  describe "connected?/2" do
    test "returns true when integration exists for scoped user and provider" do
      scope = user_scope_fixture()
      _integration = github_integration_fixture(scope.user)

      assert IntegrationRepository.connected?(scope, :github) == true
    end

    test "returns false when integration doesn't exist" do
      scope = user_scope_fixture()

      assert IntegrationRepository.connected?(scope, :github) == false
    end

    test "returns false when integration exists for different user" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _integration = github_integration_fixture(scope1.user)

      assert IntegrationRepository.connected?(scope2, :github) == false
    end

    test "efficient check without loading full integration record" do
      scope = user_scope_fixture()
      _integration = github_integration_fixture(scope.user)

      # Should be efficient boolean check
      assert IntegrationRepository.connected?(scope, :github) == true
      assert IntegrationRepository.connected?(scope, :gitlab) == false
    end

    test "checks all providers independently" do
      scope = user_scope_fixture()

      _github = github_integration_fixture(scope.user)
      _gitlab = gitlab_integration_fixture(scope.user)

      assert IntegrationRepository.connected?(scope, :github) == true
      assert IntegrationRepository.connected?(scope, :gitlab) == true
      assert IntegrationRepository.connected?(scope, :bitbucket) == false
    end

    test "enforces multi-tenant isolation" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _integration1 = github_integration_fixture(scope1.user)

      assert IntegrationRepository.connected?(scope1, :github) == true
      assert IntegrationRepository.connected?(scope2, :github) == false
    end
  end
end
