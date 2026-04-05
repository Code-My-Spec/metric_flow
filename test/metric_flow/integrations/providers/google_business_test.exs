defmodule MetricFlow.Integrations.Providers.GoogleBusinessTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Providers.GoogleBusiness

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

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    @describetag :integration

    test "returns keyword list with required OAuth configuration keys" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleBusiness.config()

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
        config = GoogleBusiness.config()

        client_id = Keyword.fetch!(config, :client_id)
        assert is_binary(client_id)
        assert byte_size(client_id) > 0
        assert client_id == Application.fetch_env!(:metric_flow, :google_client_id)
      end)
    end

    test "includes redirect_uri pointing to the google_business callback path" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleBusiness.config()
        endpoint_url = MetricFlowWeb.Endpoint.url()

        redirect_uri = Keyword.fetch!(config, :redirect_uri)
        assert String.starts_with?(redirect_uri, endpoint_url)
        assert String.ends_with?(redirect_uri, "/integrations/oauth/callback/google_business")
      end)
    end

    test "includes authorization_params with business.manage scope" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleBusiness.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.keyword?(auth_params)
        scope = Keyword.fetch!(auth_params, :scope)
        assert String.contains?(scope, "email")
        assert String.contains?(scope, "profile")
        assert String.contains?(scope, "business.manage")
      end)
    end

    test "includes access_type offline for refresh token support" do
      if not has_google_credentials?(), do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = GoogleBusiness.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.fetch!(auth_params, :access_type) == "offline"
      end)
    end

    test "raises when google_client_id is not configured" do
      original = Application.get_env(:metric_flow, :google_client_id)
      Application.delete_env(:metric_flow, :google_client_id)

      on_exit(fn ->
        if original, do: Application.put_env(:metric_flow, :google_client_id, original)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> GoogleBusiness.config() end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.Google module" do
      assert GoogleBusiness.strategy() == Assent.Strategy.Google
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok tuple with normalized user data for valid Google user data" do
      assert {:ok, normalized} = GoogleBusiness.normalize_user(valid_user_data())

      assert is_map(normalized)
      assert normalized.provider_user_id == "104029371234567890123"
      assert normalized.email == "jane.doe@example.com"
      assert normalized.name == "Jane Doe"
      assert normalized.username == "jane.doe@example.com"
      assert normalized.avatar_url == "https://lh3.googleusercontent.com/a/jane_doe_photo"
      assert normalized.hosted_domain == "example.com"
    end

    test "delegates to Google provider for normalization" do
      assert {:ok, from_business} = GoogleBusiness.normalize_user(valid_user_data())
      assert {:ok, from_google} = MetricFlow.Integrations.Providers.Google.normalize_user(valid_user_data())

      assert from_business == from_google
    end

    test "returns error :invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = GoogleBusiness.normalize_user("not a map")
      assert {:error, :invalid_user_data} = GoogleBusiness.normalize_user(42)
      assert {:error, :invalid_user_data} = GoogleBusiness.normalize_user([:list])
    end
  end
end
