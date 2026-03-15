defmodule MetricFlow.Integrations.Providers.FacebookTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Providers.Facebook

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp has_facebook_credentials? do
    Application.get_env(:metric_flow, :facebook_app_id) != nil and
      Application.get_env(:metric_flow, :facebook_app_secret) != nil
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "sub" => "1234567890123456",
      "email" => "jane.doe@example.com",
      "name" => "Jane Doe",
      "picture" => "https://graph.facebook.com/1234567890123456/picture"
    }
  end

  defp minimal_user_data do
    %{"sub" => "9876543210987654"}
  end

  defp integer_sub_user_data do
    %{
      "sub" => 1_234_567_890_123_456,
      "email" => "jane.doe@example.com",
      "name" => "Jane Doe",
      "picture" => "https://graph.facebook.com/1234567890123456/picture"
    }
  end

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    @describetag :integration

    test "returns keyword list with required OAuth configuration keys" do
      if not has_facebook_credentials?(), do: flunk("Facebook OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = Facebook.config()

        assert Keyword.keyword?(config)
        assert Keyword.has_key?(config, :client_id)
        assert Keyword.has_key?(config, :client_secret)
        assert Keyword.has_key?(config, :redirect_uri)
        assert Keyword.has_key?(config, :authorization_params)
      end)
    end

    test "includes client_id from application config" do
      if not has_facebook_credentials?(), do: flunk("Facebook OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = Facebook.config()

        client_id = Keyword.fetch!(config, :client_id)
        assert is_binary(client_id)
        assert byte_size(client_id) > 0
        assert client_id == Application.fetch_env!(:metric_flow, :facebook_app_id)
      end)
    end

    test "includes client_secret from application config" do
      if not has_facebook_credentials?(), do: flunk("Facebook OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = Facebook.config()

        client_secret = Keyword.fetch!(config, :client_secret)
        assert is_binary(client_secret)
        assert byte_size(client_secret) > 0
        assert client_secret == Application.fetch_env!(:metric_flow, :facebook_app_secret)
      end)
    end

    test "includes redirect_uri pointing to the facebook_ads callback path" do
      if not has_facebook_credentials?(), do: flunk("Facebook OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = Facebook.config()

        redirect_uri = Keyword.fetch!(config, :redirect_uri)
        assert is_binary(redirect_uri)
        assert String.ends_with?(redirect_uri, "/integrations/oauth/callback/facebook_ads")
      end)
    end

    test "includes authorization_params with ads_read scope" do
      if not has_facebook_credentials?(), do: flunk("Facebook OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = Facebook.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.keyword?(auth_params)
        scope = Keyword.fetch!(auth_params, :scope)
        assert String.contains?(scope, "ads_read")
      end)
    end

    test "raises ArgumentError when facebook_app_id is not configured" do
      original = Application.get_env(:metric_flow, :facebook_app_id)
      Application.delete_env(:metric_flow, :facebook_app_id)

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :facebook_app_id, original),
          else: Application.delete_env(:metric_flow, :facebook_app_id)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> Facebook.config() end)
      end
    end

    test "raises ArgumentError when facebook_app_secret is not configured" do
      original_id = Application.get_env(:metric_flow, :facebook_app_id)
      original_secret = Application.get_env(:metric_flow, :facebook_app_secret)

      Application.put_env(:metric_flow, :facebook_app_id, "test_app_id")
      Application.delete_env(:metric_flow, :facebook_app_secret)

      on_exit(fn ->
        if original_id,
          do: Application.put_env(:metric_flow, :facebook_app_id, original_id),
          else: Application.delete_env(:metric_flow, :facebook_app_id)

        if original_secret,
          do: Application.put_env(:metric_flow, :facebook_app_secret, original_secret),
          else: Application.delete_env(:metric_flow, :facebook_app_secret)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> Facebook.config() end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.Facebook module" do
      assert Facebook.strategy() == Assent.Strategy.Facebook
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok tuple with normalized user data for valid Facebook user data" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert is_map(normalized)
      assert normalized.provider_user_id == "1234567890123456"
      assert normalized.email == "jane.doe@example.com"
      assert normalized.name == "Jane Doe"
      assert normalized.username == "jane.doe@example.com"
      assert normalized.avatar_url == "https://graph.facebook.com/1234567890123456/picture"
    end

    test "extracts provider_user_id from \"sub\" field as string" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert normalized.provider_user_id == "1234567890123456"
      assert is_binary(normalized.provider_user_id)
    end

    test "converts integer \"sub\" to string provider_user_id" do
      assert {:ok, normalized} = Facebook.normalize_user(integer_sub_user_data())

      assert is_binary(normalized.provider_user_id)
      assert normalized.provider_user_id == "1234567890123456"
    end

    test "extracts email from \"email\" field" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert normalized.email == "jane.doe@example.com"
    end

    test "extracts name from \"name\" field" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert normalized.name == "Jane Doe"
    end

    test "uses email as username" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert normalized.username == "jane.doe@example.com"
      assert normalized.username == normalized.email
    end

    test "extracts avatar_url from \"picture\" field" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert normalized.avatar_url == "https://graph.facebook.com/1234567890123456/picture"
    end

    test "handles missing optional fields (name, picture, email) gracefully with nil" do
      assert {:ok, normalized} = Facebook.normalize_user(minimal_user_data())

      assert normalized.provider_user_id == "9876543210987654"
      assert is_nil(normalized.email)
      assert is_nil(normalized.name)
      assert is_nil(normalized.username)
      assert is_nil(normalized.avatar_url)
    end

    test "returns error :missing_provider_user_id when \"sub\" is missing" do
      user_data = Map.delete(valid_user_data(), "sub")

      assert {:error, :missing_provider_user_id} = Facebook.normalize_user(user_data)
    end

    test "returns error :missing_provider_user_id when \"sub\" is nil" do
      user_data = Map.put(valid_user_data(), "sub", nil)

      assert {:error, :missing_provider_user_id} = Facebook.normalize_user(user_data)
    end

    test "returns error :invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = Facebook.normalize_user("not a map")
      assert {:error, :invalid_user_data} = Facebook.normalize_user(42)
      assert {:error, :invalid_user_data} = Facebook.normalize_user([:list])
    end

    test "normalized data has correct key types (all atoms)" do
      assert {:ok, normalized} = Facebook.normalize_user(valid_user_data())

      assert Map.keys(normalized) |> Enum.all?(&is_atom/1)
    end

    test "handles minimal user data with only required \"sub\" field" do
      assert {:ok, normalized} = Facebook.normalize_user(minimal_user_data())

      assert normalized.provider_user_id == "9876543210987654"
      assert is_nil(normalized.email)
      assert is_nil(normalized.name)
      assert is_nil(normalized.avatar_url)
    end

    test "normalizes multiple different Facebook users independently" do
      user_a = %{"sub" => "111", "email" => "alice@example.com", "name" => "Alice"}
      user_b = %{"sub" => "222", "email" => "bob@example.com", "name" => "Bob"}

      assert {:ok, normalized_a} = Facebook.normalize_user(user_a)
      assert {:ok, normalized_b} = Facebook.normalize_user(user_b)

      assert normalized_a.provider_user_id == "111"
      assert normalized_a.email == "alice@example.com"
      assert normalized_a.name == "Alice"

      assert normalized_b.provider_user_id == "222"
      assert normalized_b.email == "bob@example.com"
      assert normalized_b.name == "Bob"
    end
  end
end
