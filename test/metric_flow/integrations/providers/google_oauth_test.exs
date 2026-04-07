defmodule MetricFlow.Integrations.Providers.GoogleOauthTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Integrations.Providers.GoogleOauth

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "sub" => "104029371234567890",
      "email" => "user@example.com",
      "name" => "Test User",
      "picture" => "https://example.com/photo.jpg"
    }
  end

  defp user_data_with_id do
    %{
      "id" => "104029371234567890",
      "email" => "user@example.com",
      "name" => "Test User"
    }
  end

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    setup do
      prev_id = Application.get_env(:metric_flow, :google_oauth_client_id)
      prev_secret = Application.get_env(:metric_flow, :google_oauth_client_secret)
      Application.put_env(:metric_flow, :google_oauth_client_id, "test_id")
      Application.put_env(:metric_flow, :google_oauth_client_secret, "test_secret")

      on_exit(fn ->
        if prev_id, do: Application.put_env(:metric_flow, :google_oauth_client_id, prev_id), else: Application.delete_env(:metric_flow, :google_oauth_client_id)
        if prev_secret, do: Application.put_env(:metric_flow, :google_oauth_client_secret, prev_secret), else: Application.delete_env(:metric_flow, :google_oauth_client_secret)
      end)

      :ok
    end

    test "returns keyword list with required OAuth configuration keys" do
      config = GoogleOauth.config()
      assert Keyword.has_key?(config, :client_id)
      assert Keyword.has_key?(config, :client_secret)
      assert Keyword.has_key?(config, :redirect_uri)
      assert Keyword.has_key?(config, :authorization_params)
    end

    test "includes client_id from application config" do
      config = GoogleOauth.config()
      assert Keyword.get(config, :client_id) == "test_id"
    end

    test "includes client_secret from application config" do
      config = GoogleOauth.config()
      assert Keyword.get(config, :client_secret) == "test_secret"
    end

    test "includes redirect_uri with /integrations/oauth/callback/google_oauth path" do
      config = GoogleOauth.config()
      assert String.ends_with?(Keyword.get(config, :redirect_uri), "/app/integrations/oauth/callback/google_oauth")
    end

    test "includes authorization_params with read scope" do
      config = GoogleOauth.config()
      params = Keyword.get(config, :authorization_params)
      assert Keyword.get(params, :scope) == "read"
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.OAuth2 module" do
      assert GoogleOauth.strategy() == Assent.Strategy.OAuth2
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok tuple with normalized user data for valid input" do
      assert {:ok, normalized} = GoogleOauth.normalize_user(valid_user_data())
      assert is_map(normalized)
    end

    test "extracts provider_user_id from sub field" do
      {:ok, normalized} = GoogleOauth.normalize_user(valid_user_data())
      assert normalized.provider_user_id == "104029371234567890"
    end

    test "falls back to id field for provider_user_id" do
      {:ok, normalized} = GoogleOauth.normalize_user(user_data_with_id())
      assert normalized.provider_user_id == "104029371234567890"
    end

    test "extracts email from email field" do
      {:ok, normalized} = GoogleOauth.normalize_user(valid_user_data())
      assert normalized.email == "user@example.com"
    end

    test "returns error :invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = GoogleOauth.normalize_user("not a map")
      assert {:error, :invalid_user_data} = GoogleOauth.normalize_user(nil)
    end
  end
end
