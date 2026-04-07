defmodule MetricFlow.Integrations.Providers.AnthropicTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Integrations.Providers.Anthropic

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "sub" => "user_abc123",
      "email" => "dev@example.com",
      "name" => "Dev User",
      "picture" => "https://example.com/avatar.png"
    }
  end

  defp user_data_with_id do
    %{
      "id" => "user_abc123",
      "email" => "dev@example.com",
      "name" => "Dev User"
    }
  end

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    setup do
      # Set temporary config values for the test
      prev_id = Application.get_env(:metric_flow, :anthropic_client_id)
      prev_secret = Application.get_env(:metric_flow, :anthropic_client_secret)
      Application.put_env(:metric_flow, :anthropic_client_id, "test_client_id")
      Application.put_env(:metric_flow, :anthropic_client_secret, "test_client_secret")

      on_exit(fn ->
        if prev_id, do: Application.put_env(:metric_flow, :anthropic_client_id, prev_id), else: Application.delete_env(:metric_flow, :anthropic_client_id)
        if prev_secret, do: Application.put_env(:metric_flow, :anthropic_client_secret, prev_secret), else: Application.delete_env(:metric_flow, :anthropic_client_secret)
      end)

      :ok
    end

    test "returns keyword list with required OAuth configuration keys" do
      config = Anthropic.config()
      assert Keyword.has_key?(config, :client_id)
      assert Keyword.has_key?(config, :client_secret)
      assert Keyword.has_key?(config, :redirect_uri)
      assert Keyword.has_key?(config, :authorization_params)
    end

    test "includes client_id from application config" do
      config = Anthropic.config()
      assert Keyword.get(config, :client_id) == "test_client_id"
    end

    test "includes client_secret from application config" do
      config = Anthropic.config()
      assert Keyword.get(config, :client_secret) == "test_client_secret"
    end

    test "includes redirect_uri with /integrations/oauth/callback/anthropic path" do
      config = Anthropic.config()
      assert String.ends_with?(Keyword.get(config, :redirect_uri), "/integrations/oauth/callback/anthropic")
    end

    test "includes authorization_params with read scope" do
      config = Anthropic.config()
      params = Keyword.get(config, :authorization_params)
      assert Keyword.get(params, :scope) == "read"
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.OAuth2 module" do
      assert Anthropic.strategy() == Assent.Strategy.OAuth2
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok tuple with normalized user data for valid input" do
      assert {:ok, normalized} = Anthropic.normalize_user(valid_user_data())
      assert is_map(normalized)
    end

    test "extracts provider_user_id from sub field" do
      {:ok, normalized} = Anthropic.normalize_user(valid_user_data())
      assert normalized.provider_user_id == "user_abc123"
    end

    test "falls back to id field for provider_user_id" do
      {:ok, normalized} = Anthropic.normalize_user(user_data_with_id())
      assert normalized.provider_user_id == "user_abc123"
    end

    test "extracts email from email field" do
      {:ok, normalized} = Anthropic.normalize_user(valid_user_data())
      assert normalized.email == "dev@example.com"
    end

    test "returns error :invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = Anthropic.normalize_user("not a map")
      assert {:error, :invalid_user_data} = Anthropic.normalize_user(nil)
    end
  end
end
