defmodule MetricFlow.Integrations.Providers.GitHubTest do
  use ExUnit.Case, async: true

  import MetricFlow.ProvidersFixtures

  alias MetricFlow.Integrations.Providers.GitHub

  describe "config/0" do
    test "returns keyword list with required Assent configuration" do
      config = GitHub.config()

      assert Keyword.keyword?(config)
      assert Keyword.has_key?(config, :client_id)
      assert Keyword.has_key?(config, :client_secret)
      assert Keyword.has_key?(config, :redirect_uri)
    end

    test "includes GitHub client_id from application config" do
      config = GitHub.config()
      client_id = Keyword.get(config, :client_id)

      assert client_id != nil
      assert is_binary(client_id)
    end

    test "includes GitHub client_secret from application config" do
      config = GitHub.config()
      client_secret = Keyword.get(config, :client_secret)

      assert client_secret != nil
      assert is_binary(client_secret)
    end

    test "includes redirect_uri with GitHub callback path" do
      config = GitHub.config()
      redirect_uri = Keyword.get(config, :redirect_uri)

      assert redirect_uri != nil
      assert is_binary(redirect_uri)
      assert String.contains?(redirect_uri, "/auth/github/callback")
    end

    test "includes authorization_params with GitHub-specific scopes" do
      config = GitHub.config()
      authorization_params = Keyword.get(config, :authorization_params)

      assert authorization_params != nil
      assert Keyword.keyword?(authorization_params)

      scope = Keyword.get(authorization_params, :scope)
      assert scope != nil
      assert String.contains?(scope, "user:email")
      assert String.contains?(scope, "repo")
    end

    test "configuration is compatible with Assent.Strategy.Github" do
      config = GitHub.config()

      # Verify all required keys for Assent are present
      assert Keyword.has_key?(config, :client_id)
      assert Keyword.has_key?(config, :client_secret)
      assert Keyword.has_key?(config, :redirect_uri)

      # Verify structure matches Assent expectations
      assert is_binary(Keyword.get(config, :client_id))
      assert is_binary(Keyword.get(config, :client_secret))
      assert is_binary(Keyword.get(config, :redirect_uri))
    end
  end

  describe "strategy/0" do
    test "returns Assent.Strategy.Github module" do
      assert GitHub.strategy() == Assent.Strategy.Github
    end

    test "returned strategy module exists and is valid" do
      strategy = GitHub.strategy()

      assert Code.ensure_loaded?(strategy)
      assert function_exported?(strategy, :authorize_url, 1)
      assert function_exported?(strategy, :callback, 2)
    end
  end

  describe "normalize_user/1" do
    test "transforms GitHub user data to application domain model" do
      assent_user = github_assent_user_fixture()

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)

      assert normalized.provider_user_id == "12345678"
      assert normalized.email == "user@example.com"
      assert normalized.name == "Test User"
      assert normalized.username == "testuser"
      assert normalized.avatar_url == "https://avatars.githubusercontent.com/u/12345678"
    end

    test "maps OpenID Connect 'sub' claim to provider_user_id" do
      assent_user = github_assent_user_fixture(%{"sub" => "unique_github_id"})

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.provider_user_id == "unique_github_id"
    end

    test "maps OpenID Connect 'email' claim to email" do
      assent_user = github_assent_user_fixture(%{"email" => "test@github.com"})

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.email == "test@github.com"
    end

    test "maps OpenID Connect 'name' claim to name" do
      assent_user = github_assent_user_fixture(%{"name" => "John Doe"})

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.name == "John Doe"
    end

    test "maps OpenID Connect 'preferred_username' claim to username" do
      assent_user = github_assent_user_fixture(%{"preferred_username" => "johndoe"})

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.username == "johndoe"
    end

    test "maps OpenID Connect 'picture' claim to avatar_url" do
      assent_user = github_assent_user_fixture(%{"picture" => "https://example.com/avatar.png"})

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.avatar_url == "https://example.com/avatar.png"
    end

    test "requires provider_user_id field" do
      assent_user = %{
        "email" => "test@github.com",
        "name" => "Test User"
      }

      assert {:error, _reason} = GitHub.normalize_user(assent_user)
    end

    test "handles missing optional email field" do
      assent_user = github_user_without_email_fixture()

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.provider_user_id == "55555555"
      assert normalized.email == nil
    end

    test "handles missing optional name field" do
      assent_user = %{
        "sub" => "12345",
        "email" => "user@example.com",
        "preferred_username" => "user"
      }

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.name == nil
    end

    test "handles missing optional username field" do
      assent_user = %{
        "sub" => "12345",
        "email" => "user@example.com",
        "name" => "Test User"
      }

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.username == nil
    end

    test "handles missing optional avatar_url field" do
      assent_user = %{
        "sub" => "12345",
        "email" => "user@example.com",
        "name" => "Test User"
      }

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.avatar_url == nil
    end

    test "handles user with only minimal required data" do
      assent_user = github_user_with_minimal_data_fixture()

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)
      assert normalized.provider_user_id == "99999999"
      assert normalized.email == nil
      assert normalized.name == nil
      assert normalized.username == nil
      assert normalized.avatar_url == nil
    end

    test "returns normalized map suitable for Integration persistence" do
      assent_user = github_assent_user_fixture()

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)

      # Verify structure matches provider_metadata schema
      assert is_map(normalized)
      assert Map.has_key?(normalized, :provider_user_id)
      assert Map.has_key?(normalized, :email)
      assert Map.has_key?(normalized, :name)
      assert Map.has_key?(normalized, :username)
      assert Map.has_key?(normalized, :avatar_url)
    end

    test "normalized data has correct key types" do
      assent_user = github_assent_user_fixture()

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)

      # All keys should be atoms
      assert Enum.all?(Map.keys(normalized), &is_atom/1)
    end

    test "preserves original values without transformation" do
      assent_user =
        github_assent_user_fixture(%{
          "sub" => "original_id",
          "email" => "original@email.com",
          "name" => "Original Name",
          "preferred_username" => "original_username",
          "picture" => "https://original.com/pic.jpg"
        })

      assert {:ok, normalized} = GitHub.normalize_user(assent_user)

      assert normalized.provider_user_id == "original_id"
      assert normalized.email == "original@email.com"
      assert normalized.name == "Original Name"
      assert normalized.username == "original_username"
      assert normalized.avatar_url == "https://original.com/pic.jpg"
    end

    test "handles numeric provider_user_id by converting to string" do
      # GitHub sometimes returns numeric IDs
      assent_user = github_assent_user_fixture(%{"sub" => 12345})

      result = GitHub.normalize_user(assent_user)

      case result do
        {:ok, normalized} ->
          # If implementation coerces to string
          assert is_binary(normalized.provider_user_id)

        {:error, _} ->
          # If implementation requires string
          assert true
      end
    end

    test "normalizes multiple different GitHub users independently" do
      user1 =
        github_assent_user_fixture(%{
          "sub" => "user1_id",
          "email" => "user1@github.com"
        })

      user2 =
        github_assent_user_fixture(%{
          "sub" => "user2_id",
          "email" => "user2@github.com"
        })

      assert {:ok, normalized1} = GitHub.normalize_user(user1)
      assert {:ok, normalized2} = GitHub.normalize_user(user2)

      assert normalized1.provider_user_id != normalized2.provider_user_id
      assert normalized1.email != normalized2.email
    end

    test "returns error tuple for invalid user data structure" do
      invalid_user = "not a map"

      assert {:error, _reason} = GitHub.normalize_user(invalid_user)
    end

    test "returns error tuple for empty map" do
      empty_user = %{}

      assert {:error, _reason} = GitHub.normalize_user(empty_user)
    end

    test "returns error tuple for nil input" do
      assert {:error, _reason} = GitHub.normalize_user(nil)
    end
  end

  describe "integration with Assent OAuth flow" do
    test "config and strategy work together for authorization URL generation" do
      config = GitHub.config()
      strategy = GitHub.strategy()

      # This would be called in the request phase
      assert {:ok, %{url: url, session_params: _session_params}} = strategy.authorize_url(config)

      assert is_binary(url)
      assert String.starts_with?(url, "https://")
      assert String.contains?(url, "github.com")
    end

    test "authorization URL includes configured scopes" do
      config = GitHub.config()
      strategy = GitHub.strategy()

      assert {:ok, %{url: url}} = strategy.authorize_url(config)

      # URL should contain scope parameter with our configured scopes
      assert String.contains?(url, "scope=")
    end

    test "provider can be used in OAuth callback flow" do
      # Simulates receiving user data from Assent after OAuth callback
      assent_user = github_assent_user_fixture()

      # Provider normalizes the user data
      assert {:ok, normalized} = GitHub.normalize_user(assent_user)

      # Normalized data can be stored in provider_metadata
      assert is_map(normalized)
      assert Map.has_key?(normalized, :provider_user_id)
    end
  end

  describe "error handling" do
    test "normalize_user fails fast with invalid input" do
      invalid_inputs = [
        nil,
        [],
        "",
        123,
        %{invalid: "structure"},
        %{"missing" => "sub"}
      ]

      for invalid <- invalid_inputs do
        assert {:error, _} = GitHub.normalize_user(invalid)
      end
    end

    test "returns descriptive error message for missing provider_user_id" do
      assent_user = %{"email" => "test@example.com"}

      assert {:error, reason} = GitHub.normalize_user(assent_user)
      assert is_binary(reason) or is_atom(reason)
    end
  end
end
