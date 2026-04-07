defmodule MetricFlow.Integrations.Providers.GoogleAdsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Providers.GoogleAds

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp has_google_credentials? do
    Application.get_env(:metric_flow, :google_client_id) != nil and
      Application.get_env(:metric_flow, :google_client_secret) != nil
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "sub" => "104029371234567890123",
      "email" => "jane.doe@example.com",
      "name" => "Jane Doe",
      "picture" => "https://lh3.googleusercontent.com/a/jane_doe_photo",
      "hd" => "example.com"
    }
  end

  defp personal_account_user_data do
    %{
      "sub" => "987654321098765432109",
      "email" => "personal.user@gmail.com",
      "name" => "Personal User",
      "picture" => "https://lh3.googleusercontent.com/a/personal_photo"
    }
  end

  defp workspace_user_data do
    %{
      "sub" => "111222333444555666777",
      "email" => "employee@workspace-corp.com",
      "name" => "Workspace Employee",
      "picture" => "https://lh3.googleusercontent.com/a/employee_photo",
      "hd" => "workspace-corp.com"
    }
  end

  defp minimal_user_data do
    %{"sub" => "000111222333444555666"}
  end

  defp integer_sub_user_data do
    %{
      "sub" => 104_029_371_234_567_890_123,
      "email" => "jane.doe@example.com",
      "name" => "Jane Doe",
      "picture" => "https://lh3.googleusercontent.com/a/jane_doe_photo",
      "hd" => "example.com"
    }
  end

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    @describetag :integration

    test "returns keyword list with required OAuth configuration keys" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        assert Keyword.keyword?(config)
        assert Keyword.has_key?(config, :client_id)
        assert Keyword.has_key?(config, :client_secret)
        assert Keyword.has_key?(config, :redirect_uri)
        assert Keyword.has_key?(config, :authorization_params)
      end)
    end

    test "includes client_id from application config" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        client_id = Keyword.fetch!(config, :client_id)
        assert is_binary(client_id)
        assert byte_size(client_id) > 0
        assert client_id == Application.fetch_env!(:metric_flow, :google_client_id)
      end)
    end

    test "includes client_secret from application config" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        client_secret = Keyword.fetch!(config, :client_secret)
        assert is_binary(client_secret)
        assert byte_size(client_secret) > 0
        assert client_secret == Application.fetch_env!(:metric_flow, :google_client_secret)
      end)
    end

    test "includes redirect_uri with \"/app/integrations/oauth/callback/google_ads\" path" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()
        endpoint_url = MetricFlowWeb.Endpoint.url()

        redirect_uri = Keyword.fetch!(config, :redirect_uri)
        assert String.starts_with?(redirect_uri, endpoint_url)
        assert String.ends_with?(redirect_uri, "/app/integrations/oauth/callback/google_ads")
      end)
    end

    test "includes authorization_params with adwords scope" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        scope = Keyword.fetch!(auth_params, :scope)
        assert String.contains?(scope, "https://www.googleapis.com/auth/adwords")
      end)
    end

    test "includes email and profile scopes in addition to adwords" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        scope = Keyword.fetch!(auth_params, :scope)
        assert String.contains?(scope, "email")
        assert String.contains?(scope, "profile")
        assert String.contains?(scope, "https://www.googleapis.com/auth/adwords")
      end)
    end

    test "includes access_type \"offline\" for refresh token support" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.fetch!(auth_params, :access_type) == "offline"
      end)
    end

    test "includes prompt \"consent\" to force consent screen" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleAds.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.fetch!(auth_params, :prompt) == "consent"
      end)
    end

    test "raises ArgumentError when google_client_id is not configured" do
      original = Application.get_env(:metric_flow, :google_client_id)
      Application.delete_env(:metric_flow, :google_client_id)

      on_exit(fn ->
        if original, do: Application.put_env(:metric_flow, :google_client_id, original)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> GoogleAds.config() end)
      end
    end

    test "raises ArgumentError when google_client_secret is not configured" do
      original = Application.get_env(:metric_flow, :google_client_secret)
      Application.delete_env(:metric_flow, :google_client_secret)

      on_exit(fn ->
        if original, do: Application.put_env(:metric_flow, :google_client_secret, original)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> GoogleAds.config() end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.Google module" do
      assert GoogleAds.strategy() == Assent.Strategy.Google
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok tuple with normalized user data for valid Google user data" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert is_map(normalized)
      assert normalized.provider_user_id == "104029371234567890123"
      assert normalized.email == "jane.doe@example.com"
      assert normalized.name == "Jane Doe"
      assert normalized.username == "jane.doe@example.com"
      assert normalized.avatar_url == "https://lh3.googleusercontent.com/a/jane_doe_photo"
      assert normalized.hosted_domain == "example.com"
    end

    test "extracts provider_user_id from \"sub\" field" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert normalized.provider_user_id == "104029371234567890123"
    end

    test "extracts email from \"email\" field" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert normalized.email == "jane.doe@example.com"
    end

    test "extracts name from \"name\" field" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert normalized.name == "Jane Doe"
    end

    test "uses email as username" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert normalized.username == "jane.doe@example.com"
      assert normalized.username == normalized.email
    end

    test "extracts avatar_url from \"picture\" field" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert normalized.avatar_url == "https://lh3.googleusercontent.com/a/jane_doe_photo"
    end

    test "extracts hosted_domain from \"hd\" field for Workspace accounts" do
      assert {:ok, normalized} = GoogleAds.normalize_user(workspace_user_data())

      assert normalized.hosted_domain == "workspace-corp.com"
    end

    test "handles missing optional fields (name, picture, hd) gracefully" do
      assert {:ok, normalized} = GoogleAds.normalize_user(minimal_user_data())

      assert normalized.provider_user_id == "000111222333444555666"
      assert is_nil(normalized.name)
      assert is_nil(normalized.avatar_url)
      assert is_nil(normalized.hosted_domain)
    end

    test "returns error :missing_provider_user_id when \"sub\" is nil" do
      user_data = Map.put(valid_user_data(), "sub", nil)

      assert {:error, :missing_provider_user_id} = GoogleAds.normalize_user(user_data)
    end

    test "returns error :invalid_provider_user_id when \"sub\" is invalid type" do
      user_data = Map.put(valid_user_data(), "sub", %{"nested" => "map"})

      assert {:error, :invalid_provider_user_id} = GoogleAds.normalize_user(user_data)
    end

    test "returns error :invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = GoogleAds.normalize_user("not a map")
      assert {:error, :invalid_user_data} = GoogleAds.normalize_user(42)
      assert {:error, :invalid_user_data} = GoogleAds.normalize_user([:list])
    end

    test "converts integer provider_user_id to string" do
      assert {:ok, normalized} = GoogleAds.normalize_user(integer_sub_user_data())

      assert is_binary(normalized.provider_user_id)
    end

    test "accepts string provider_user_id as-is" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert normalized.provider_user_id == "104029371234567890123"
      assert is_binary(normalized.provider_user_id)
    end

    test "handles missing \"sub\" field" do
      user_data = Map.delete(valid_user_data(), "sub")

      assert {:error, :missing_provider_user_id} = GoogleAds.normalize_user(user_data)
    end

    test "normalized data has correct key types (all atoms)" do
      assert {:ok, normalized} = GoogleAds.normalize_user(valid_user_data())

      assert Map.keys(normalized) |> Enum.all?(&is_atom/1)
    end

    test "handles personal Google accounts without hosted domain" do
      assert {:ok, normalized} = GoogleAds.normalize_user(personal_account_user_data())

      assert is_nil(normalized.hosted_domain)
      assert normalized.email == "personal.user@gmail.com"
      assert normalized.username == "personal.user@gmail.com"
    end

    test "handles Google Workspace users with hosted domain" do
      assert {:ok, normalized} = GoogleAds.normalize_user(workspace_user_data())

      assert normalized.hosted_domain == "workspace-corp.com"
      assert normalized.email == "employee@workspace-corp.com"
      assert normalized.username == "employee@workspace-corp.com"
    end
  end
end
