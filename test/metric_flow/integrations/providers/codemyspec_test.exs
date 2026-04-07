defmodule MetricFlow.Integrations.Providers.CodemyspecTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Providers.Codemyspec

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp has_codemyspec_credentials? do
    Application.get_env(:metric_flow, :codemyspec_client_id) != nil and
      Application.get_env(:metric_flow, :codemyspec_client_secret) != nil
  end

  defp put_stub_credentials do
    original_url = Application.get_env(:metric_flow, :codemyspec_url)
    original_id = Application.get_env(:metric_flow, :codemyspec_client_id)
    original_secret = Application.get_env(:metric_flow, :codemyspec_client_secret)

    Application.put_env(:metric_flow, :codemyspec_url, "https://app.codemyspec.com")
    Application.put_env(:metric_flow, :codemyspec_client_id, "stub-client-id")
    Application.put_env(:metric_flow, :codemyspec_client_secret, "stub-client-secret")

    on_exit(fn ->
      if original_url,
        do: Application.put_env(:metric_flow, :codemyspec_url, original_url),
        else: Application.delete_env(:metric_flow, :codemyspec_url)

      if original_id,
        do: Application.put_env(:metric_flow, :codemyspec_client_id, original_id),
        else: Application.delete_env(:metric_flow, :codemyspec_client_id)

      if original_secret,
        do: Application.put_env(:metric_flow, :codemyspec_client_secret, original_secret),
        else: Application.delete_env(:metric_flow, :codemyspec_client_secret)
    end)
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "id" => "42",
      "email" => "developer@example.com"
    }
  end

  defp integer_id_user_data do
    %{
      "id" => 42,
      "email" => "developer@example.com"
    }
  end

  defp minimal_user_data do
    %{"id" => "99"}
  end

  defp extra_fields_user_data do
    %{
      "id" => "77",
      "email" => "extra@example.com",
      "role" => "admin",
      "organization" => "ACME Corp"
    }
  end

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    setup do
      put_stub_credentials()
      :ok
    end

    test "returns keyword list with required OAuth configuration keys" do
      capture_log(fn ->
        config = Codemyspec.config()

        assert Keyword.keyword?(config)
        assert Keyword.has_key?(config, :client_id)
        assert Keyword.has_key?(config, :client_secret)
        assert Keyword.has_key?(config, :redirect_uri)
        assert Keyword.has_key?(config, :base_url)
        assert Keyword.has_key?(config, :authorize_url)
        assert Keyword.has_key?(config, :token_url)
        assert Keyword.has_key?(config, :user_url)
        assert Keyword.has_key?(config, :auth_method)
        assert Keyword.has_key?(config, :authorization_params)
      end)
    end

    test "includes client_id from application config" do
      capture_log(fn ->
        config = Codemyspec.config()

        client_id = Keyword.fetch!(config, :client_id)
        assert is_binary(client_id)
        assert byte_size(client_id) > 0
        assert client_id == Application.fetch_env!(:metric_flow, :codemyspec_client_id)
      end)
    end

    test "includes redirect_uri pointing to the codemyspec callback path" do
      capture_log(fn ->
        config = Codemyspec.config()
        endpoint_url = MetricFlowWeb.Endpoint.url()

        redirect_uri = Keyword.fetch!(config, :redirect_uri)
        assert is_binary(redirect_uri)
        assert String.starts_with?(redirect_uri, endpoint_url)
        assert String.ends_with?(redirect_uri, "/app/integrations/oauth/callback/codemyspec")
      end)
    end

    test "includes authorize_url and token_url derived from base_url" do
      capture_log(fn ->
        config = Codemyspec.config()
        base_url = Keyword.fetch!(config, :base_url)

        authorize_url = Keyword.fetch!(config, :authorize_url)
        token_url = Keyword.fetch!(config, :token_url)

        assert String.starts_with?(authorize_url, base_url)
        assert String.starts_with?(token_url, base_url)
      end)
    end

    test "includes auth_method of :client_secret_post" do
      capture_log(fn ->
        config = Codemyspec.config()

        assert Keyword.fetch!(config, :auth_method) == :client_secret_post
      end)
    end

    test "includes authorization_params with read write scope" do
      capture_log(fn ->
        config = Codemyspec.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.keyword?(auth_params)
        scope = Keyword.fetch!(auth_params, :scope)
        assert scope == "read write"
      end)
    end

    test "raises when codemyspec_url is not configured" do
      original = Application.get_env(:metric_flow, :codemyspec_url)
      Application.delete_env(:metric_flow, :codemyspec_url)

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :codemyspec_url, original),
          else: Application.delete_env(:metric_flow, :codemyspec_url)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> Codemyspec.config() end)
      end
    end

    test "raises when codemyspec_client_id is not configured" do
      original = Application.get_env(:metric_flow, :codemyspec_client_id)
      Application.delete_env(:metric_flow, :codemyspec_client_id)

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :codemyspec_client_id, original),
          else: Application.delete_env(:metric_flow, :codemyspec_client_id)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> Codemyspec.config() end)
      end
    end

    test "raises when codemyspec_client_secret is not configured" do
      original = Application.get_env(:metric_flow, :codemyspec_client_secret)
      Application.delete_env(:metric_flow, :codemyspec_client_secret)

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :codemyspec_client_secret, original),
          else: Application.delete_env(:metric_flow, :codemyspec_client_secret)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> Codemyspec.config() end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.OAuth2 module" do
      assert Codemyspec.strategy() == Assent.Strategy.OAuth2
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok tuple with normalized user data for valid input" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert is_map(normalized)
      assert normalized.provider_user_id == "42"
      assert normalized.email == "developer@example.com"
      assert normalized.name == "developer@example.com"
      assert normalized.username == "developer@example.com"
      assert is_nil(normalized.avatar_url)
    end

    test "extracts provider_user_id from \"id\" field as string" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert is_binary(normalized.provider_user_id)
      assert normalized.provider_user_id == "42"
    end

    test "converts integer id to string for provider_user_id" do
      assert {:ok, normalized} = Codemyspec.normalize_user(integer_id_user_data())

      assert is_binary(normalized.provider_user_id)
      assert normalized.provider_user_id == "42"
    end

    test "uses email as name" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert normalized.name == "developer@example.com"
      assert normalized.name == normalized.email
    end

    test "uses email as username" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert normalized.username == "developer@example.com"
      assert normalized.username == normalized.email
    end

    test "sets avatar_url to nil" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert is_nil(normalized.avatar_url)
    end

    test "handles minimal user data with only id field" do
      assert {:ok, normalized} = Codemyspec.normalize_user(minimal_user_data())

      assert normalized.provider_user_id == "99"
      assert is_nil(normalized.email)
      assert is_nil(normalized.name)
      assert is_nil(normalized.username)
      assert is_nil(normalized.avatar_url)
    end

    test "ignores extra fields not in the domain model" do
      assert {:ok, normalized} = Codemyspec.normalize_user(extra_fields_user_data())

      assert normalized.provider_user_id == "77"
      assert normalized.email == "extra@example.com"
      refute Map.has_key?(normalized, :role)
      refute Map.has_key?(normalized, :organization)
    end

    test "normalized map uses only atom keys" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert Map.keys(normalized) |> Enum.all?(&is_atom/1)
    end

    test "normalized map has all required keys" do
      assert {:ok, normalized} = Codemyspec.normalize_user(valid_user_data())

      assert Map.has_key?(normalized, :provider_user_id)
      assert Map.has_key?(normalized, :email)
      assert Map.has_key?(normalized, :name)
      assert Map.has_key?(normalized, :username)
      assert Map.has_key?(normalized, :avatar_url)
    end

    test "returns error :invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = Codemyspec.normalize_user("not a map")
      assert {:error, :invalid_user_data} = Codemyspec.normalize_user(42)
      assert {:error, :invalid_user_data} = Codemyspec.normalize_user([:list])
    end

    test "returns error :invalid_user_data when input is nil" do
      assert {:error, :invalid_user_data} = Codemyspec.normalize_user(nil)
    end

    test "normalizes multiple different users independently" do
      user_a = %{"id" => "100", "email" => "alice@example.com"}
      user_b = %{"id" => "200", "email" => "bob@example.com"}

      assert {:ok, normalized_a} = Codemyspec.normalize_user(user_a)
      assert {:ok, normalized_b} = Codemyspec.normalize_user(user_b)

      assert normalized_a.provider_user_id == "100"
      assert normalized_a.email == "alice@example.com"
      assert normalized_a.username == "alice@example.com"

      assert normalized_b.provider_user_id == "200"
      assert normalized_b.email == "bob@example.com"
      assert normalized_b.username == "bob@example.com"
    end
  end
end
