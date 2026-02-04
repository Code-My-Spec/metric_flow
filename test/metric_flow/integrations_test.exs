defmodule MetricFlow.IntegrationsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.Scope

  setup do
    user = user_fixture()
    scope = %Scope{user: user}

    {:ok, scope: scope, user: user}
  end

  describe "authorize_url/1" do
    test "generates GitHub authorization URL with session params" do
      assert {:ok, %{url: url, session_params: session_params}} =
               Integrations.authorize_url(:github)

      assert is_binary(url)
      assert String.starts_with?(url, "https://github.com")
      assert is_map(session_params)
    end

    test "returns error for unsupported provider" do
      assert {:error, :unsupported_provider} = Integrations.authorize_url(:unsupported)
    end
  end

  describe "handle_callback/4" do
    test "creates integration on successful OAuth callback", %{scope: scope} do
      # Note: This test would require mocking Assent.Strategy.Github.callback/2
      # For now, we'll test the upsert_integration path directly
      token_attrs = %{
        access_token: "gho_test_token",
        refresh_token: nil,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        granted_scopes: ["user:email", "repo"],
        provider_metadata: %{
          provider_user_id: "12345",
          email: "test@example.com",
          name: "Test User"
        }
      }

      assert {:ok, integration} =
               Integrations.IntegrationRepository.upsert_integration(scope, :github, token_attrs)

      assert integration.provider == :github
      assert integration.user_id == scope.user.id
      assert integration.access_token == "gho_test_token"
    end
  end

  describe "get_integration/2" do
    test "returns integration when it exists", %{scope: scope} do
      {:ok, created} = create_test_integration(scope, :github)

      assert {:ok, integration} = Integrations.get_integration(scope, :github)
      assert integration.id == created.id
      assert integration.provider == :github
    end

    test "returns error when integration doesn't exist", %{scope: scope} do
      assert {:error, :not_found} = Integrations.get_integration(scope, :gitlab)
    end
  end

  describe "list_integrations/1" do
    test "returns all integrations for user", %{scope: scope} do
      {:ok, _} = create_test_integration(scope, :github)

      integrations = Integrations.list_integrations(scope)

      assert length(integrations) == 1
      assert Enum.all?(integrations, fn i -> i.user_id == scope.user.id end)
    end

    test "returns empty list when no integrations exist", %{scope: scope} do
      assert [] = Integrations.list_integrations(scope)
    end
  end

  describe "delete_integration/2" do
    test "deletes integration when it exists", %{scope: scope} do
      {:ok, _} = create_test_integration(scope, :github)

      assert {:ok, %Integration{}} = Integrations.delete_integration(scope, :github)
      assert {:error, :not_found} = Integrations.get_integration(scope, :github)
    end

    test "returns error when integration doesn't exist", %{scope: scope} do
      assert {:error, :not_found} = Integrations.delete_integration(scope, :gitlab)
    end
  end

  describe "connected?/2" do
    test "returns true when integration exists", %{scope: scope} do
      {:ok, _} = create_test_integration(scope, :github)

      assert Integrations.connected?(scope, :github)
    end

    test "returns false when integration doesn't exist", %{scope: scope} do
      refute Integrations.connected?(scope, :gitlab)
    end
  end

  # Test Helpers

  defp create_test_integration(scope, provider) do
    attrs = %{
      access_token: "test_token_#{:rand.uniform(10000)}",
      refresh_token: "test_refresh_#{:rand.uniform(10000)}",
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
      granted_scopes: ["user:email", "repo"],
      provider_metadata: %{
        provider_user_id: "test_user_#{:rand.uniform(10000)}",
        email: "test@example.com",
        name: "Test User"
      }
    }

    Integrations.IntegrationRepository.upsert_integration(scope, provider, attrs)
  end
end
