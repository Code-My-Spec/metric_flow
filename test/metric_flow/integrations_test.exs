defmodule MetricFlow.IntegrationsTest do
  use MetricFlowTest.DataCase, async: true

  import ExUnit.CaptureLog
  import MetricFlowTest.UsersFixtures
  import ReqCassette

  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.Scope

  @cassette_dir "test/cassettes/oauth"

  # ---------------------------------------------------------------------------
  # Test provider stubs
  #
  # The context's authorize_url/2 and handle_callback/5 orchestrate OAuth flows
  # at the application boundary. We use stub provider modules here so tests
  # remain fast and deterministic without requiring network access or real OAuth
  # credentials.
  #
  # Each stub is registered in the context's providers map via Application.put_env
  # in the setup block. The context is expected to read its providers map from
  # Application.get_env(:metric_flow, :oauth_providers), falling back to the
  # default map of real providers.
  #
  # Stub naming convention:
  #   :stub             — happy path, space-separated scope string, expires_in present
  #   :stub_no_expiry   — no expires_in in token, expects default of 1 year
  #   :stub_comma_scope — comma-separated scope string
  #   :stub_array_scope — scope delivered as a list
  #   :stub_token_error — strategy.callback returns an error
  #   :stub_norm_error  — normalize_user returns an error
  #   :stub_revoke      — provider exports revoke_token/1
  #   :stub_revoke_fail — provider exports revoke_token/1 but it fails
  #   :stub_no_revoke   — provider does not export revoke_token/1
  #   :stub_refresh_raises — strategy raises an exception during refresh
  # ---------------------------------------------------------------------------

  defmodule StubStrategy do
    @moduledoc false

    @state "test-csrf-state-token"
    @auth_url "https://stub.example.com/oauth/authorize?response_type=code&state=#{@state}"

    def default_config(_config), do: []

    def authorize_url(_config) do
      {:ok, %{url: @auth_url, session_params: %{state: @state}}}
    end

    def callback(config, _params) do
      token_base = %{
        "access_token" => "stub-access-token",
        "refresh_token" => "stub-refresh-token"
      }

      token = Map.merge(token_base, Keyword.get(config, :token_overrides, %{}))
      user = Keyword.get(config, :user_override, %{"sub" => "stub-user-id", "email" => "stub@example.com"})
      {:ok, %{token: token, user: user}}
    end

    def refresh_access_token(_config, %{"refresh_token" => refresh_token})
        when is_binary(refresh_token) do
      {:ok,
       %{
         "access_token" => "refreshed-access-token",
         "refresh_token" => refresh_token,
         "expires_in" => 3600,
         "scope" => "email profile"
       }}
    end

    def state, do: @state
    def auth_url, do: @auth_url
  end

  defmodule StubStrategyNoRefresh do
    @moduledoc false

    def default_config(_config), do: []

    def authorize_url(_config) do
      {:ok, %{url: "https://stub.example.com/oauth/authorize", session_params: %{state: "s"}}}
    end

    def callback(_config, _params) do
      {:ok, %{token: %{"access_token" => "stub-token"}, user: %{}}}
    end

    def refresh_access_token(_config, _token) do
      {:error, :not_supported}
    end
  end

  defmodule StubStrategyRefreshFail do
    @moduledoc false

    def default_config(_config), do: []

    def authorize_url(_config) do
      {:ok, %{url: "https://stub.example.com/oauth/authorize", session_params: %{state: "s"}}}
    end

    def callback(_config, _params) do
      {:ok, %{token: %{"access_token" => "stub-token"}, user: %{}}}
    end

    def refresh_access_token(_config, _token) do
      {:error, :invalid_grant}
    end
  end

  defmodule StubStrategyRaises do
    @moduledoc false

    def default_config(_config), do: []

    def authorize_url(_config) do
      {:ok, %{url: "https://stub.example.com/oauth/authorize", session_params: %{state: "s"}}}
    end

    def callback(_config, _params) do
      {:ok, %{token: %{"access_token" => "stub-token"}, user: %{}}}
    end

    def refresh_access_token(_config, _token) do
      raise RuntimeError, "unexpected failure during token refresh"
    end
  end

  defmodule StubStrategyTokenError do
    @moduledoc false

    def default_config(_config), do: []

    def authorize_url(_config) do
      {:ok, %{url: "https://stub.example.com/oauth/authorize", session_params: %{state: "s"}}}
    end

    def callback(_config, _params) do
      {:error, :token_exchange_failed}
    end
  end

  defmodule StubProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => "email profile"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub} = data) when is_binary(sub) do
      {:ok,
       %{
         provider_user_id: sub,
         email: Map.get(data, "email"),
         name: Map.get(data, "name"),
         username: Map.get(data, "email"),
         avatar_url: nil
       }}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderNoExpiry do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_no_expiry/callback",
        token_overrides: %{"scope" => "email profile"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderCommaScope do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_comma_scope/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => "email,profile,openid"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderArrayScope do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_array_scope/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => ["email", "profile", "openid"]}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderTokenError do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_token_error/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategyTokenError

    @impl true
    def normalize_user(_), do: {:error, :should_not_be_called}
  end

  defmodule StubProviderNormalizeError do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_norm_error/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => "email"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(_user_data), do: {:error, :normalization_failed}
  end

  defmodule StubProviderWithRevoke do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_revoke/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => "email profile"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}

    @impl true
    def revoke_token(_token), do: :ok
  end

  defmodule StubProviderRevokeFailure do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_revoke_fail/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => "email profile"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}

    @impl true
    def revoke_token(_token), do: {:error, :revocation_failed}
  end

  defmodule StubProviderNoRevoke do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_no_revoke/callback",
        token_overrides: %{"expires_in" => 3600, "scope" => "email profile"}
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderRefreshable do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_refreshable/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderRefreshNoSupport do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_no_refresh/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategyNoRefresh

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderRefreshFail do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_refresh_fail/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategyRefreshFail

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderRefreshRaises do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_refresh_raises/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlow.IntegrationsTest.StubStrategyRaises

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok, %{provider_user_id: sub, email: nil, name: nil, username: nil, avatar_url: nil}}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  @stub_providers %{
    stub: MetricFlow.IntegrationsTest.StubProvider,
    stub_no_expiry: MetricFlow.IntegrationsTest.StubProviderNoExpiry,
    stub_comma_scope: MetricFlow.IntegrationsTest.StubProviderCommaScope,
    stub_array_scope: MetricFlow.IntegrationsTest.StubProviderArrayScope,
    stub_token_error: MetricFlow.IntegrationsTest.StubProviderTokenError,
    stub_norm_error: MetricFlow.IntegrationsTest.StubProviderNormalizeError,
    stub_revoke: MetricFlow.IntegrationsTest.StubProviderWithRevoke,
    stub_revoke_fail: MetricFlow.IntegrationsTest.StubProviderRevokeFailure,
    stub_no_revoke: MetricFlow.IntegrationsTest.StubProviderNoRevoke,
    stub_refreshable: MetricFlow.IntegrationsTest.StubProviderRefreshable,
    stub_no_refresh: MetricFlow.IntegrationsTest.StubProviderRefreshNoSupport,
    stub_refresh_fail: MetricFlow.IntegrationsTest.StubProviderRefreshFail,
    stub_refresh_raises: MetricFlow.IntegrationsTest.StubProviderRefreshRaises
  }

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3_600, :second)
  end

  defp insert_integration!(user_id, provider, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: future_expires_at(),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "stub-user-id"}
    }

    attrs = Map.merge(defaults, overrides)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  defp valid_session_params do
    %{state: StubStrategy.state()}
  end

  defp valid_callback_params do
    %{"code" => "valid-auth-code", "state" => StubStrategy.state()}
  end

  # ---------------------------------------------------------------------------
  # Setup — inject stub providers so authorize_url/2 and handle_callback/5
  # can resolve test providers without touching real OAuth endpoints.
  # ---------------------------------------------------------------------------

  setup do
    original = Application.get_env(:metric_flow, :oauth_providers)

    Application.put_env(:metric_flow, :oauth_providers, @stub_providers)

    on_exit(fn ->
      if original do
        Application.put_env(:metric_flow, :oauth_providers, original)
      else
        Application.delete_env(:metric_flow, :oauth_providers)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # list_providers/0
  # ---------------------------------------------------------------------------

  describe "list_providers/0" do
    test "returns list of provider atoms from the default configuration" do
      # Restore default providers so we exercise the real default map
      Application.delete_env(:metric_flow, :oauth_providers)

      on_exit(fn ->
        Application.put_env(:metric_flow, :oauth_providers, @stub_providers)
      end)

      capture_log(fn ->
        providers = Integrations.list_providers()

        assert is_list(providers)
        assert providers != []
        assert Enum.all?(providers, &is_atom/1)
        assert :google in providers
      end)
    end

    test "reflects custom providers when application config overrides the default" do
      capture_log(fn ->
        providers = Integrations.list_providers()

        assert is_list(providers)
        assert :stub in providers
        assert :stub_no_expiry in providers
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # authorize_url/2 — stub tests
  # ---------------------------------------------------------------------------

  describe "authorize_url/2" do
    test "returns ok tuple with url and session_params for supported provider" do
      capture_log(fn ->
        assert {:ok, result} = Integrations.authorize_url(:stub)

        assert Map.has_key?(result, :url)
        assert Map.has_key?(result, :session_params)
      end)
    end

    test "returned url is a valid authorization endpoint for the provider" do
      capture_log(fn ->
        assert {:ok, %{url: url}} = Integrations.authorize_url(:stub)

        assert is_binary(url)
        assert String.starts_with?(url, "https://")
      end)
    end

    test "session_params contain state for CSRF protection" do
      capture_log(fn ->
        assert {:ok, %{session_params: session_params}} = Integrations.authorize_url(:stub)

        assert Map.has_key?(session_params, :state)
        assert is_binary(session_params.state)
        assert byte_size(session_params.state) > 0
      end)
    end

    test "returns error tuple with :unsupported_provider for unknown provider atom" do
      capture_log(fn ->
        assert {:error, :unsupported_provider} = Integrations.authorize_url(:nonexistent_provider)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # authorize_url/2 — real Google provider via Assent with cassette recording
  # ---------------------------------------------------------------------------

  describe "authorize_url/2 with real Google provider" do
    @describetag :integration

    setup do
      # Restore real providers so we exercise the actual Google module + Assent
      Application.delete_env(:metric_flow, :oauth_providers)

      on_exit(fn ->
        Application.put_env(:metric_flow, :oauth_providers, @stub_providers)
      end)

      :ok
    end

    test "generates a valid Google OAuth authorization URL through Assent" do
      if Application.get_env(:metric_flow, :google_client_id) == nil,
        do: flunk("Google OAuth credentials not configured in .env.test")

      capture_log(fn ->
        with_cassette "google_authorize_url",
          [
            cassette_dir: @cassette_dir,
            mode: :replay,
            match_requests_on: [:method, :uri],
            filter_request_headers: ["authorization"]
          ],
          fn plug ->
            opts = [http_adapter: {Assent.HTTPAdapter.Req, [plug: plug]}]

            assert {:ok, %{url: url, session_params: session_params}} =
                     Integrations.authorize_url(:google, opts)

            assert String.contains?(url, "accounts.google.com")
            assert String.contains?(url, "response_type=code")
            assert String.contains?(url, "scope=")
            assert is_map(session_params)
          end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_callback/5
  # ---------------------------------------------------------------------------

  describe "handle_callback/5" do
    test "returns ok tuple with integration for a valid callback" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert %Integration{} = integration
        assert integration.provider == :stub
        assert integration.user_id == scope.user.id
      end)
    end

    test "upserts integration with encrypted tokens" do
      {user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert integration.user_id == user.id
        assert is_binary(integration.access_token)
        assert byte_size(integration.access_token) > 0
      end)
    end

    test "stores normalized provider_metadata from provider" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert is_map(integration.provider_metadata)
      end)
    end

    test "calculates expires_at from token expires_in" do
      {_user, scope} = user_with_scope()

      before_call = DateTime.utc_now()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert %DateTime{} = integration.expires_at
        assert DateTime.compare(integration.expires_at, before_call) == :gt
      end)
    end

    test "defaults expires_at to 1 year when expires_in is not present" do
      {_user, scope} = user_with_scope()

      one_year_from_now = DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub_no_expiry,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert %DateTime{} = integration.expires_at
        diff = DateTime.diff(integration.expires_at, one_year_from_now, :second)
        assert abs(diff) < 60
      end)
    end

    test "parses granted_scopes from token scope string" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert is_list(integration.granted_scopes)
        assert integration.granted_scopes != []
      end)
    end

    test "handles scope as space-separated string" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert "email" in integration.granted_scopes
        assert "profile" in integration.granted_scopes
      end)
    end

    test "handles scope as comma-separated string" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub_comma_scope,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert is_list(integration.granted_scopes)
        assert integration.granted_scopes != []
      end)
    end

    test "handles scope as list" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:ok, integration} =
                 Integrations.handle_callback(
                   scope,
                   :stub_array_scope,
                   valid_session_params(),
                   valid_callback_params()
                 )

        assert is_list(integration.granted_scopes)
        assert integration.granted_scopes != []
      end)
    end

    test "returns error for unsupported provider" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:error, :unsupported_provider} =
                 Integrations.handle_callback(
                   scope,
                   :nonexistent_provider,
                   valid_session_params(),
                   valid_callback_params()
                 )
      end)
    end

    test "returns error when token exchange fails" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:error, _reason} =
                 Integrations.handle_callback(
                   scope,
                   :stub_token_error,
                   valid_session_params(),
                   valid_callback_params()
                 )
      end)
    end

    test "returns error when user normalization fails" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:error, _reason} =
                 Integrations.handle_callback(
                   scope,
                   :stub_norm_error,
                   valid_session_params(),
                   valid_callback_params()
                 )
      end)
    end

    test "returns error when OAuth state does not match session state" do
      {_user, scope} = user_with_scope()

      mismatched_callback_params = %{
        "code" => "valid-auth-code",
        "state" => "wrong-csrf-state-token"
      }

      capture_log(fn ->
        assert {:error, :state_mismatch} =
                 Integrations.handle_callback(
                   scope,
                   :stub,
                   valid_session_params(),
                   mismatched_callback_params
                 )
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # disconnect/2
  # ---------------------------------------------------------------------------

  describe "disconnect/2" do
    test "returns ok tuple with the deleted integration on success" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_no_revoke)

      capture_log(fn ->
        assert {:ok, deleted} = Integrations.disconnect(scope, :stub_no_revoke)

        assert deleted.id == integration.id
        assert Repo.get(Integration, integration.id) == nil
      end)
    end

    test "returns error tuple with :not_found when integration does not exist" do
      {_user, scope} = user_with_scope()

      capture_log(fn ->
        assert {:error, :not_found} = Integrations.disconnect(scope, :stub_no_revoke)
      end)
    end

    test "calls provider's revoke_token/1 when the function is exported" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :stub_revoke)

      capture_log(fn ->
        assert {:ok, _deleted} = Integrations.disconnect(scope, :stub_revoke)
      end)
    end

    test "deletes the integration even when token revocation fails" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_revoke_fail)

      capture_log(fn ->
        assert {:ok, deleted} = Integrations.disconnect(scope, :stub_revoke_fail)

        assert deleted.id == integration.id
        assert Repo.get(Integration, integration.id) == nil
      end)
    end

    test "skips revocation when provider does not export revoke_token/1" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_no_revoke)

      capture_log(fn ->
        assert {:ok, deleted} = Integrations.disconnect(scope, :stub_no_revoke)

        assert deleted.id == integration.id
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # refresh_token/2
  # ---------------------------------------------------------------------------

  describe "refresh_token/2" do
    test "returns ok tuple with updated integration when refresh succeeds" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_refreshable)

      capture_log(fn ->
        assert {:ok, updated} = Integrations.refresh_token(scope, integration)

        assert %Integration{} = updated
        assert updated.id == integration.id
        assert updated.access_token == "refreshed-access-token"
      end)
    end

    test "returns error when provider strategy does not support refresh" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_no_refresh)

      capture_log(fn ->
        assert {:error, _reason} = Integrations.refresh_token(scope, integration)
      end)
    end

    test "returns error when the refresh request fails" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_refresh_fail)

      capture_log(fn ->
        assert {:error, :invalid_grant} = Integrations.refresh_token(scope, integration)
      end)
    end

    test "returns error for unsupported provider" do
      {_user, scope} = user_with_scope()

      integration = %Integration{
        id: 0,
        provider: :nonexistent_provider,
        access_token: "some-token",
        refresh_token: "some-refresh-token",
        expires_at: future_expires_at(),
        user_id: 0,
        granted_scopes: [],
        provider_metadata: %{}
      }

      capture_log(fn ->
        assert {:error, :unsupported_provider} = Integrations.refresh_token(scope, integration)
      end)
    end

    test "returns :token_refresh_failed when an exception is raised during refresh" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_refresh_raises)

      capture_log(fn ->
        assert {:error, :token_refresh_failed} = Integrations.refresh_token(scope, integration)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # get_integration/2 — delegates to IntegrationRepository
  # ---------------------------------------------------------------------------

  describe "get_integration/2" do
    test "returns ok tuple with integration when found" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_no_revoke)

      assert {:ok, result} = Integrations.get_integration(scope, :stub_no_revoke)

      assert result.id == integration.id
      assert result.provider == :stub_no_revoke
    end

    test "returns error tuple with :not_found when not found" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = Integrations.get_integration(scope, :stub_no_revoke)
    end

    test "integration has decrypted tokens via Cloak" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :stub_no_revoke)

      assert {:ok, result} = Integrations.get_integration(scope, :stub_no_revoke)

      assert is_binary(result.access_token)
      assert byte_size(result.access_token) > 0
      assert is_binary(result.refresh_token)
      assert byte_size(result.refresh_token) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # list_integrations/1 — delegates to IntegrationRepository
  # ---------------------------------------------------------------------------

  describe "list_integrations/1" do
    test "returns list of integrations for the user" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :stub_no_revoke)
      insert_integration!(user.id, :stub_revoke)

      results = Integrations.list_integrations(scope)

      assert length(results) == 2
      assert Enum.all?(results, &(&1.user_id == user.id))
    end

    test "returns empty list when user has no integrations" do
      {_user, scope} = user_with_scope()

      assert Integrations.list_integrations(scope) == []
    end

    test "integrations are ordered by most recently created" do
      {user, scope} = user_with_scope()
      first = insert_integration!(user.id, :stub_no_revoke)
      second = insert_integration!(user.id, :stub_revoke)

      results = Integrations.list_integrations(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end
  end

  # ---------------------------------------------------------------------------
  # list_all_active_integrations/0 — delegates to IntegrationRepository
  # ---------------------------------------------------------------------------

  describe "list_all_active_integrations/0" do
    test "returns all integrations regardless of user" do
      {user_a, _scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_a.id, :stub_no_revoke)
      insert_integration!(user_b.id, :stub_revoke)

      results = Integrations.list_all_active_integrations()

      assert length(results) >= 2
      user_ids = Enum.map(results, & &1.user_id)
      assert user_a.id in user_ids
      assert user_b.id in user_ids
    end

    test "returns empty list when no integrations exist" do
      assert Integrations.list_all_active_integrations() == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_integration_by_id/1 — delegates to IntegrationRepository
  # ---------------------------------------------------------------------------

  describe "get_integration_by_id/1" do
    test "returns ok tuple with integration when found" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_no_revoke)

      assert {:ok, result} = Integrations.get_integration_by_id(integration.id)

      assert result.id == integration.id
    end

    test "returns error tuple with :not_found when not found" do
      assert {:error, :not_found} = Integrations.get_integration_by_id(-1)
    end
  end

  # ---------------------------------------------------------------------------
  # delete_integration/2 — delegates to IntegrationRepository
  # ---------------------------------------------------------------------------

  describe "delete_integration/2" do
    test "returns ok tuple with the deleted integration" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :stub_no_revoke)

      assert {:ok, deleted} = Integrations.delete_integration(scope, :stub_no_revoke)

      assert deleted.id == integration.id
      assert Repo.get(Integration, integration.id) == nil
    end

    test "returns error tuple with :not_found when integration does not exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = Integrations.delete_integration(scope, :stub_no_revoke)
    end
  end

  # ---------------------------------------------------------------------------
  # connected?/2 — delegates to IntegrationRepository
  # ---------------------------------------------------------------------------

  describe "connected?/2" do
    test "returns true when integration exists" do
      {user, scope} = user_with_scope()
      insert_integration!(user.id, :stub_no_revoke)

      assert Integrations.connected?(scope, :stub_no_revoke)
    end

    test "returns false when integration does not exist" do
      {_user, scope} = user_with_scope()

      refute Integrations.connected?(scope, :stub_no_revoke)
    end
  end
end
