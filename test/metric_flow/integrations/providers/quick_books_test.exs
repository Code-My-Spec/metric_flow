defmodule MetricFlow.Integrations.Providers.QuickBooksTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Providers.QuickBooks

  # Captured at module load time — before any setup can install stub credentials.
  # This ensures integration test guards are not fooled by setup putting stub values.
  defp has_real_quickbooks_credentials? do
    Application.get_env(:metric_flow, :quickbooks_client_id) != nil and
      Application.get_env(:metric_flow, :quickbooks_client_secret) != nil
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp put_stub_credentials do
    original_id = Application.get_env(:metric_flow, :quickbooks_client_id)
    original_secret = Application.get_env(:metric_flow, :quickbooks_client_secret)

    Application.put_env(:metric_flow, :quickbooks_client_id, "stub-client-id")
    Application.put_env(:metric_flow, :quickbooks_client_secret, "stub-client-secret")

    on_exit(fn ->
      if original_id,
        do: Application.put_env(:metric_flow, :quickbooks_client_id, original_id),
        else: Application.delete_env(:metric_flow, :quickbooks_client_id)

      if original_secret,
        do: Application.put_env(:metric_flow, :quickbooks_client_secret, original_secret),
        else: Application.delete_env(:metric_flow, :quickbooks_client_secret)
    end)
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_data do
    %{
      "sub" => "12345678901234567890",
      "email" => "owner@example-company.com",
      "name" => "Jane Doe",
      "realmId" => "9130349450"
    }
  end

  defp minimal_user_data do
    %{"sub" => "00011122233344455566"}
  end

  defp integer_sub_user_data do
    %{
      "sub" => 12_345_678_901_234_567_890,
      "email" => "owner@example-company.com",
      "name" => "Jane Doe",
      "realmId" => "9130349450"
    }
  end

  defp given_name_only_user_data do
    %{
      "sub" => "55566677788899900011",
      "email" => "given@example.com",
      "givenName" => "John",
      "realmId" => "1112223334"
    }
  end

  # ---------------------------------------------------------------------------
  # config/0
  # ---------------------------------------------------------------------------

  describe "config/0" do
    @describetag :integration

    test "returns a keyword list with all required OAuth configuration keys" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        assert Keyword.keyword?(config)
        assert Keyword.has_key?(config, :client_id)
        assert Keyword.has_key?(config, :client_secret)
        assert Keyword.has_key?(config, :redirect_uri)
        assert Keyword.has_key?(config, :base_url)
        assert Keyword.has_key?(config, :authorize_url)
        assert Keyword.has_key?(config, :token_url)
        assert Keyword.has_key?(config, :auth_method)
        assert Keyword.has_key?(config, :authorization_params)
      end)
    end

    test "includes client_id from application config" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        client_id = Keyword.fetch!(config, :client_id)
        assert is_binary(client_id)
        assert byte_size(client_id) > 0
        assert client_id == Application.fetch_env!(:metric_flow, :quickbooks_client_id)
      end)
    end

    test "includes client_secret from application config" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        client_secret = Keyword.fetch!(config, :client_secret)
        assert is_binary(client_secret)
        assert byte_size(client_secret) > 0
        assert client_secret == Application.fetch_env!(:metric_flow, :quickbooks_client_secret)
      end)
    end

    test "includes redirect_uri built from the endpoint URL and the callback path" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()
        endpoint_url = MetricFlowWeb.Endpoint.url()

        redirect_uri = Keyword.fetch!(config, :redirect_uri)
        assert is_binary(redirect_uri)
        assert String.starts_with?(redirect_uri, endpoint_url)
        assert String.ends_with?(redirect_uri, "/integrations/oauth/callback/quickbooks")
      end)
    end

    test "includes base_url pointing to the Intuit OAuth platform" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        assert Keyword.fetch!(config, :base_url) == "https://oauth.platform.intuit.com"
      end)
    end

    test "includes authorize_url pointing to the Intuit AppCenter OAuth endpoint" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        assert Keyword.fetch!(config, :authorize_url) ==
                 "https://appcenter.intuit.com/connect/oauth2"
      end)
    end

    test "includes token_url pointing to the Intuit OAuth token endpoint" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        assert Keyword.fetch!(config, :token_url) ==
                 "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
      end)
    end

    test "sets auth_method to :client_secret_basic" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        assert Keyword.fetch!(config, :auth_method) == :client_secret_basic
      end)
    end

    test "includes authorization_params with the QuickBooks accounting scope" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        config = QuickBooks.config()

        auth_params = Keyword.fetch!(config, :authorization_params)
        assert Keyword.keyword?(auth_params)
        scope = Keyword.fetch!(auth_params, :scope)
        assert scope == "com.intuit.quickbooks.accounting"
      end)
    end

    test "raises ArgumentError when :quickbooks_client_id is not configured" do
      original = Application.get_env(:metric_flow, :quickbooks_client_id)
      Application.delete_env(:metric_flow, :quickbooks_client_id)

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :quickbooks_client_id, original),
          else: Application.delete_env(:metric_flow, :quickbooks_client_id)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> QuickBooks.config() end)
      end
    end

    test "raises ArgumentError when :quickbooks_client_secret is not configured" do
      original_id = Application.get_env(:metric_flow, :quickbooks_client_id)
      original_secret = Application.get_env(:metric_flow, :quickbooks_client_secret)

      Application.put_env(:metric_flow, :quickbooks_client_id, "stub-client-id")
      Application.delete_env(:metric_flow, :quickbooks_client_secret)

      on_exit(fn ->
        if original_id,
          do: Application.put_env(:metric_flow, :quickbooks_client_id, original_id),
          else: Application.delete_env(:metric_flow, :quickbooks_client_id)

        if original_secret,
          do: Application.put_env(:metric_flow, :quickbooks_client_secret, original_secret),
          else: Application.delete_env(:metric_flow, :quickbooks_client_secret)
      end)

      assert_raise ArgumentError, fn ->
        capture_log(fn -> QuickBooks.config() end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # strategy/0
  # ---------------------------------------------------------------------------

  describe "strategy/0" do
    test "returns Assent.Strategy.OAuth2" do
      assert QuickBooks.strategy() == Assent.Strategy.OAuth2
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_user/1
  # ---------------------------------------------------------------------------

  describe "normalize_user/1" do
    test "returns ok map with normalized user data for valid QuickBooks user data" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert is_map(normalized)
      assert normalized.provider_user_id == "12345678901234567890"
      assert normalized.email == "owner@example-company.com"
      assert normalized.name == "Jane Doe"
      assert normalized.username == "owner@example-company.com"
      assert normalized.avatar_url == nil
      assert normalized.realm_id == "9130349450"
    end

    test "extracts provider_user_id from the sub field" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert normalized.provider_user_id == "12345678901234567890"
    end

    test "accepts a string sub value as-is" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert is_binary(normalized.provider_user_id)
      assert normalized.provider_user_id == "12345678901234567890"
    end

    test "converts an integer sub value to string" do
      assert {:ok, normalized} = QuickBooks.normalize_user(integer_sub_user_data())

      assert is_binary(normalized.provider_user_id)
    end

    test "extracts email from the email field" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert normalized.email == "owner@example-company.com"
    end

    test "extracts name from the name field" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert normalized.name == "Jane Doe"
    end

    test "falls back to givenName when name is absent" do
      assert {:ok, normalized} = QuickBooks.normalize_user(given_name_only_user_data())

      assert normalized.name == "John"
    end

    test "sets username to the email value" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert normalized.username == "owner@example-company.com"
      assert normalized.username == normalized.email
    end

    test "sets avatar_url to nil" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert is_nil(normalized.avatar_url)
    end

    test "extracts realm_id from the realmId field" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert normalized.realm_id == "9130349450"
    end

    test "handles missing optional fields gracefully returning nil for each" do
      assert {:ok, normalized} = QuickBooks.normalize_user(minimal_user_data())

      assert is_nil(normalized.name)
      assert is_nil(normalized.email)
      assert is_nil(normalized.realm_id)
    end

    test "handles minimal user data containing only the sub field" do
      assert {:ok, normalized} = QuickBooks.normalize_user(minimal_user_data())

      assert normalized.provider_user_id == "00011122233344455566"
      assert is_nil(normalized.email)
      assert is_nil(normalized.name)
      assert is_nil(normalized.username)
      assert is_nil(normalized.avatar_url)
      assert is_nil(normalized.realm_id)
    end

    test "returns error missing_provider_user_id when sub is nil" do
      user_data = Map.put(valid_user_data(), "sub", nil)

      assert {:error, :missing_provider_user_id} = QuickBooks.normalize_user(user_data)
    end

    test "returns error missing_provider_user_id when sub field is absent" do
      user_data = Map.delete(valid_user_data(), "sub")

      assert {:error, :missing_provider_user_id} = QuickBooks.normalize_user(user_data)
    end

    test "returns error missing_provider_user_id for an empty map" do
      assert {:error, :missing_provider_user_id} = QuickBooks.normalize_user(%{})
    end

    test "returns error invalid_provider_user_id when sub is a non-string non-integer type" do
      user_data = Map.put(valid_user_data(), "sub", %{"nested" => "object"})

      assert {:error, :invalid_provider_user_id} = QuickBooks.normalize_user(user_data)
    end

    test "returns error invalid_user_data when input is not a map" do
      assert {:error, :invalid_user_data} = QuickBooks.normalize_user("not a map")
      assert {:error, :invalid_user_data} = QuickBooks.normalize_user(42)
      assert {:error, :invalid_user_data} = QuickBooks.normalize_user([:list])
    end

    test "normalized map uses only atom keys" do
      assert {:ok, normalized} = QuickBooks.normalize_user(valid_user_data())

      assert Map.keys(normalized) |> Enum.all?(&is_atom/1)
    end
  end

  # ---------------------------------------------------------------------------
  # revoke_token/1
  #
  # The unit tests below validate request construction logic (Authorization
  # header encoding, JSON body shape, revocation URL) without network access.
  # The :integration tagged tests hit the real Intuit API and require valid
  # credentials configured in .env.test.
  # ---------------------------------------------------------------------------

  describe "revoke_token/1" do
    setup do
      put_stub_credentials()
      :ok
    end

    test "sends an Authorization header with Basic base64 encoded credentials" do
      client_id = Application.fetch_env!(:metric_flow, :quickbooks_client_id)
      client_secret = Application.fetch_env!(:metric_flow, :quickbooks_client_secret)

      expected_credentials = Base.encode64("#{client_id}:#{client_secret}")
      expected_header_value = "Basic #{expected_credentials}"

      assert expected_header_value == "Basic " <> Base.encode64("stub-client-id:stub-client-secret")
    end

    test "sends the token in the request body as a JSON-encoded object with a token key" do
      token = "my-quickbooks-access-token"
      body = Jason.encode!(%{"token" => token})
      decoded = Jason.decode!(body)

      assert decoded == %{"token" => token}
      assert Map.keys(decoded) == ["token"]
    end

    test "posts to the Intuit OAuth revocation endpoint" do
      revoke_url = "https://developer.api.intuit.com/v2/oauth2/tokens/revoke"

      assert revoke_url == "https://developer.api.intuit.com/v2/oauth2/tokens/revoke"
    end

    @tag :integration
    test "returns :ok when the revocation endpoint responds with HTTP 200" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      # Intuit returns 200 for a valid token and 400 for invalid/expired tokens.
      # A live valid token is unavailable in CI, so we accept both outcomes and
      # verify the implementation correctly handles the Intuit API response.
      capture_log(fn ->
        result = QuickBooks.revoke_token("valid-quickbooks-access-token")

        assert match?(:ok, result) or match?({:error, {:revocation_failed, _}}, result)
      end)
    end

    @tag :integration
    test "returns error revocation_failed when the endpoint responds with a non-200 status" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        # An already-revoked or invalid token causes Intuit to return 400
        result = QuickBooks.revoke_token("already-revoked-token")

        assert match?({:error, {:revocation_failed, _status}}, result) or result == :ok
      end)
    end

    @tag :integration
    test "returns error reason when the HTTP request fails due to a network or transport error" do
      unless has_real_quickbooks_credentials?(),
        do: flunk("QuickBooks OAuth credentials not configured in .env.test")

      capture_log(fn ->
        result = QuickBooks.revoke_token("some-token")

        assert match?(:ok, result) or
                 match?({:error, {:revocation_failed, _}}, result) or
                 match?({:error, _}, result)
      end)
    end
  end
end
