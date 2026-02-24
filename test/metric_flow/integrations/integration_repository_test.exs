defmodule MetricFlow.Integrations.IntegrationRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import Ecto.Query
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  defp past_expires_at do
    DateTime.add(DateTime.utc_now(), -3600, :second)
  end

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp valid_integration_attrs(user_id, provider \\ :google) do
    %{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: future_expires_at(),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "12345"}
    }
  end

  defp insert_integration!(user_id, provider, overrides \\ %{}) do
    attrs = Map.merge(valid_integration_attrs(user_id, provider), overrides)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # get_integration/2
  # ---------------------------------------------------------------------------

  describe "get_integration/2" do
    test "returns integration when it exists for scoped user and provider" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :google)

      assert {:ok, result} = IntegrationRepository.get_integration(scope, :google)
      assert result.id == integration.id
      assert result.provider == :google
    end

    test "returns error when integration doesn't exist for provider" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = IntegrationRepository.get_integration(scope, :github)
    end

    test "returns error when integration exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      insert_integration!(other_user.id, :google)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = IntegrationRepository.get_integration(scope, :google)
    end

    test "decrypts access_token and refresh_token when loading" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      assert {:ok, result} = IntegrationRepository.get_integration(scope, :google)
      assert is_binary(result.access_token)
      assert String.length(result.access_token) > 0
      assert is_binary(result.refresh_token)
      assert String.length(result.refresh_token) > 0
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_a.id, :google)
      insert_integration!(user_b.id, :google)

      assert {:ok, result} = IntegrationRepository.get_integration(scope_a, :google)
      assert result.user_id == user_a.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_integrations/1
  # ---------------------------------------------------------------------------

  describe "list_integrations/1" do
    test "returns all integrations for scoped user" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)
      insert_integration!(user.id, :github)

      results = IntegrationRepository.list_integrations(scope)

      assert length(results) == 2
    end

    test "returns empty list when no integrations exist" do
      {_user, scope} = user_with_scope()

      assert IntegrationRepository.list_integrations(scope) == []
    end

    test "only returns integrations for scoped user" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_integration!(user.id, :google)
      insert_integration!(other_user.id, :github)

      results = IntegrationRepository.list_integrations(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "orders by most recently created" do
      {user, scope} = user_with_scope()

      first = insert_integration!(user.id, :google)
      second = insert_integration!(user.id, :github)

      results = IntegrationRepository.list_integrations(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_a.id, :google)
      insert_integration!(user_b.id, :github)
      insert_integration!(user_b.id, :gitlab)

      results = IntegrationRepository.list_integrations(scope_a)

      assert length(results) == 1
      assert hd(results).user_id == user_a.id
    end
  end

  # ---------------------------------------------------------------------------
  # create_integration/2
  # ---------------------------------------------------------------------------

  describe "create_integration/2" do
    test "creates integration with valid attributes" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_integration_attrs(user.id), :user_id)

      assert {:ok, integration} = IntegrationRepository.create_integration(scope, attrs)
      assert integration.provider == :google
      assert integration.user_id == user.id
    end

    test "returns error with invalid provider" do
      {_user, scope} = user_with_scope()

      attrs = %{
        provider: :not_a_provider,
        access_token: "some-token",
        expires_at: future_expires_at()
      }

      assert {:error, changeset} = IntegrationRepository.create_integration(scope, attrs)
      refute changeset.valid?
    end

    test "returns error with missing required fields" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = IntegrationRepository.create_integration(scope, %{})
      refute changeset.valid?
    end

    test "returns error with duplicate user_id and provider" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      attrs = Map.delete(valid_integration_attrs(user.id, :google), :user_id)

      assert {:error, changeset} = IntegrationRepository.create_integration(scope, attrs)
      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same provider for different users" do
      {_user_a, scope_a} = user_with_scope()
      {_user_b, scope_b} = user_with_scope()

      attrs = %{
        provider: :google,
        access_token: "token-a",
        expires_at: future_expires_at()
      }

      assert {:ok, _integration_a} = IntegrationRepository.create_integration(scope_a, attrs)
      assert {:ok, _integration_b} = IntegrationRepository.create_integration(scope_b, attrs)
    end

    test "stores granted_scopes and provider_metadata" do
      {user, scope} = user_with_scope()

      attrs = %{
        provider: :google,
        access_token: "some-token",
        expires_at: future_expires_at(),
        granted_scopes: ["email", "openid"],
        provider_metadata: %{"sub" => "user-123"}
      }

      assert {:ok, integration} = IntegrationRepository.create_integration(scope, attrs)
      assert integration.granted_scopes == ["email", "openid"]
      assert integration.provider_metadata == %{"sub" => "user-123"}
      assert integration.user_id == user.id
    end

    test "handles integration without refresh_token" do
      {_user, scope} = user_with_scope()

      attrs = %{
        provider: :google,
        access_token: "some-token",
        expires_at: future_expires_at(),
        refresh_token: nil
      }

      assert {:ok, integration} = IntegrationRepository.create_integration(scope, attrs)
      assert integration.refresh_token == nil
    end
  end

  # ---------------------------------------------------------------------------
  # update_integration/3
  # ---------------------------------------------------------------------------

  describe "update_integration/3" do
    test "updates integration with valid attributes" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      new_token = "updated-access-token"
      new_expires_at = DateTime.add(DateTime.utc_now(), 7200, :second)

      assert {:ok, updated} =
               IntegrationRepository.update_integration(scope, :google, %{
                 access_token: new_token,
                 expires_at: new_expires_at
               })

      assert updated.access_token == new_token
    end

    test "returns error when integration doesn't exist for scoped user" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} =
               IntegrationRepository.update_integration(scope, :google, %{
                 access_token: "new-token"
               })
    end

    test "returns error when integration exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      insert_integration!(other_user.id, :google)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} =
               IntegrationRepository.update_integration(scope, :google, %{
                 access_token: "new-token"
               })
    end

    test "returns error with invalid attributes" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      assert {:error, changeset} =
               IntegrationRepository.update_integration(scope, :google, %{
                 provider: :not_a_provider
               })

      refute changeset.valid?
    end

    test "commonly used for token refresh operations" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      refreshed_attrs = %{
        access_token: "new-access-token-after-refresh",
        refresh_token: "new-refresh-token",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      assert {:ok, updated} = IntegrationRepository.update_integration(scope, :google, refreshed_attrs)
      assert updated.access_token == "new-access-token-after-refresh"
    end
  end

  # ---------------------------------------------------------------------------
  # delete_integration/2
  # ---------------------------------------------------------------------------

  describe "delete_integration/2" do
    test "deletes integration for scoped user and provider" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :google)

      assert {:ok, deleted} = IntegrationRepository.delete_integration(scope, :google)
      assert deleted.id == integration.id
      assert Repo.get(Integration, integration.id) == nil
    end

    test "returns error when integration doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = IntegrationRepository.delete_integration(scope, :google)
    end

    test "returns error when integration exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      insert_integration!(other_user.id, :google)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = IntegrationRepository.delete_integration(scope, :google)
    end

    test "removes all associated encrypted tokens" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :google)

      assert {:ok, _deleted} = IntegrationRepository.delete_integration(scope, :google)

      assert Repo.get(Integration, integration.id) == nil
    end

    test "does not affect integrations for other providers" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)
      github_integration = insert_integration!(user.id, :github)

      assert {:ok, _deleted} = IntegrationRepository.delete_integration(scope, :google)

      assert Repo.get(Integration, github_integration.id) != nil
    end
  end

  # ---------------------------------------------------------------------------
  # by_provider/2
  # ---------------------------------------------------------------------------

  describe "by_provider/2" do
    test "returns integration for scoped user and provider" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :github)

      assert {:ok, result} = IntegrationRepository.by_provider(scope, :github)
      assert result.id == integration.id
    end

    test "is alias for get_integration/2" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      get_result = IntegrationRepository.get_integration(scope, :google)
      by_provider_result = IntegrationRepository.by_provider(scope, :google)

      assert {:ok, get_integration} = get_result
      assert {:ok, by_provider_integration} = by_provider_result
      assert get_integration.id == by_provider_integration.id
    end

    test "provides semantic clarity when querying by provider" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google_ads)

      assert {:ok, result} = IntegrationRepository.by_provider(scope, :google_ads)
      assert result.provider == :google_ads
      assert result.user_id == user.id
    end
  end

  # ---------------------------------------------------------------------------
  # with_expired_tokens/1
  # ---------------------------------------------------------------------------

  describe "with_expired_tokens/1" do
    test "returns integrations where expires_at is less than current timestamp" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google, %{expires_at: past_expires_at()})

      results = IntegrationRepository.with_expired_tokens(scope)

      assert length(results) == 1
      assert hd(results).provider == :google
    end

    test "returns empty list when no integrations are expired" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google, %{expires_at: future_expires_at()})

      assert IntegrationRepository.with_expired_tokens(scope) == []
    end

    test "only returns expired integrations for scoped user" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_integration!(user.id, :google, %{expires_at: past_expires_at()})
      insert_integration!(other_user.id, :github, %{expires_at: past_expires_at()})

      results = IntegrationRepository.with_expired_tokens(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "used to identify integrations requiring token refresh" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google, %{expires_at: past_expires_at()})
      insert_integration!(user.id, :github, %{expires_at: future_expires_at()})

      results = IntegrationRepository.with_expired_tokens(scope)

      assert length(results) == 1
      assert hd(results).provider == :google
    end

    test "does not decrypt tokens when checking expiration" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google, %{expires_at: past_expires_at()})

      results = IntegrationRepository.with_expired_tokens(scope)

      assert length(results) == 1
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_a.id, :google, %{expires_at: past_expires_at()})
      insert_integration!(user_b.id, :github, %{expires_at: past_expires_at()})

      results = IntegrationRepository.with_expired_tokens(scope_a)

      assert length(results) == 1
      assert hd(results).user_id == user_a.id
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_integration/3
  # ---------------------------------------------------------------------------

  describe "upsert_integration/3" do
    test "creates new integration when none exists" do
      {user, scope} = user_with_scope()

      attrs = %{
        access_token: "first-token",
        expires_at: future_expires_at()
      }

      assert {:ok, integration} = IntegrationRepository.upsert_integration(scope, :google, attrs)
      assert integration.provider == :google
      assert integration.user_id == user.id
    end

    test "updates existing integration when one exists" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google, %{access_token: "original-token"})

      attrs = %{
        access_token: "refreshed-token",
        expires_at: future_expires_at()
      }

      assert {:ok, updated} = IntegrationRepository.upsert_integration(scope, :google, attrs)
      assert updated.access_token == "refreshed-token"
    end

    test "based on unique constraint (user_id, provider)" do
      {user, scope} = user_with_scope()

      attrs_v1 = %{
        access_token: "token-v1",
        expires_at: future_expires_at()
      }

      assert {:ok, first} = IntegrationRepository.upsert_integration(scope, :google, attrs_v1)

      attrs_v2 = %{
        access_token: "token-v2",
        expires_at: future_expires_at()
      }

      assert {:ok, second} = IntegrationRepository.upsert_integration(scope, :google, attrs_v2)
      assert first.user_id == second.user_id
      assert first.provider == second.provider

      count =
        Repo.aggregate(
          from(i in Integration, where: i.user_id == ^user.id and i.provider == :google),
          :count
        )

      assert count == 1
    end

    test "used during OAuth callback for first-time connections" do
      {_user, scope} = user_with_scope()

      oauth_attrs = %{
        access_token: "oauth-access-token",
        refresh_token: "oauth-refresh-token",
        expires_at: future_expires_at(),
        granted_scopes: ["email", "profile"],
        provider_metadata: %{"id" => "provider-user-id"}
      }

      assert {:ok, integration} = IntegrationRepository.upsert_integration(scope, :google, oauth_attrs)
      assert integration.granted_scopes == ["email", "profile"]
    end

    test "used during OAuth callback for reconnections" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google, %{access_token: "old-token"})

      new_oauth_attrs = %{
        access_token: "new-oauth-access-token",
        refresh_token: "new-refresh-token",
        expires_at: future_expires_at()
      }

      assert {:ok, updated} = IntegrationRepository.upsert_integration(scope, :google, new_oauth_attrs)
      assert updated.access_token == "new-oauth-access-token"
    end

    test "returns error with invalid attributes" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} =
               IntegrationRepository.upsert_integration(scope, :google, %{
                 access_token: nil,
                 expires_at: nil
               })

      refute changeset.valid?
    end

    test "allows different providers for same user" do
      {_user, scope} = user_with_scope()

      attrs = %{
        access_token: "some-token",
        expires_at: future_expires_at()
      }

      assert {:ok, google} = IntegrationRepository.upsert_integration(scope, :google, attrs)
      assert {:ok, github} = IntegrationRepository.upsert_integration(scope, :github, attrs)
      assert google.provider == :google
      assert github.provider == :github
    end
  end

  # ---------------------------------------------------------------------------
  # connected?/2
  # ---------------------------------------------------------------------------

  describe "connected?/2" do
    test "returns true when integration exists for scoped user and provider" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      assert IntegrationRepository.connected?(scope, :google)
    end

    test "returns false when integration doesn't exist" do
      {_user, scope} = user_with_scope()

      refute IntegrationRepository.connected?(scope, :google)
    end

    test "returns false when integration exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      insert_integration!(other_user.id, :google)

      {_user, scope} = user_with_scope()

      refute IntegrationRepository.connected?(scope, :google)
    end

    test "efficient check without loading full integration record" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :github)

      result = IntegrationRepository.connected?(scope, :github)

      assert result == true
    end

    test "checks all providers independently" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :google)

      assert IntegrationRepository.connected?(scope, :google)
      refute IntegrationRepository.connected?(scope, :github)
      refute IntegrationRepository.connected?(scope, :gitlab)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_b.id, :google)

      refute IntegrationRepository.connected?(scope_a, :google)

      insert_integration!(user_a.id, :github)
      assert IntegrationRepository.connected?(scope_a, :github)
    end
  end
end
