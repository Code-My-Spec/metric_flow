defmodule MetricFlowTest.OAuthStub do
  @moduledoc """
  OAuth provider stubs backed by cassette replay for BDD spec tests.

  Uses real `Assent.Strategy.OAuth2` strategies with a Req plug that replays
  recorded HTTP responses from cassette files in `test/cassettes/oauth/`.
  This exercises the full OAuth callback flow (controller → Integrations
  context → Assent strategy → HTTP adapter → cassette replay → provider
  normalize_user) without making real network requests.

  ## Usage in shared givens

  Call `setup_oauth_providers/0` in a given step before hitting the OAuth
  callback controller. This:

  1. Registers cassette-backed providers for each platform
  2. Stores a known CSRF state token in the OAuthStateStore
  3. Returns `on_exit` cleanup automatically

  ## Example

      given_ :with_oauth_stub_providers
      # Then hit the callback:
      conn = get(context.owner_conn, "/integrations/oauth/callback/google_ads",
        MetricFlowTest.OAuthStub.valid_callback_params())
  """

  alias MetricFlow.Integrations.OAuthStateStore

  @state_token "test-bdd-csrf-state-token"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Returns the known CSRF state token used by the stubs."
  def state_token, do: @state_token

  @doc "Returns callback params that will succeed with the cassette strategy."
  def valid_callback_params do
    %{"code" => "stub-auth-code", "state" => @state_token}
  end

  @doc "Returns callback params simulating user-denied access."
  def denied_callback_params do
    %{"error" => "access_denied", "state" => @state_token}
  end

  @doc """
  Configures cassette-backed OAuth providers in the application env and stores
  the CSRF state token in OAuthStateStore. Registers `on_exit` to restore
  the original provider config.
  """
  def setup_oauth_providers do
    original = Application.get_env(:metric_flow, :oauth_providers)

    Application.put_env(:metric_flow, :oauth_providers, cassette_providers())
    OAuthStateStore.store(@state_token, %{state: @state_token})

    ExUnit.Callbacks.on_exit(fn ->
      if original do
        Application.put_env(:metric_flow, :oauth_providers, original)
      else
        Application.delete_env(:metric_flow, :oauth_providers)
      end
    end)

    :ok
  end

  @doc "Returns the map of all cassette-backed providers."
  def cassette_providers do
    %{
      google: __MODULE__.GoogleAdsProvider,
      google_ads: __MODULE__.GoogleAdsProvider,
      google_analytics: __MODULE__.GoogleAdsProvider,
      facebook_ads: __MODULE__.FacebookAdsProvider,
      quickbooks: __MODULE__.QuickBooksProvider
    }
  end

  # ---------------------------------------------------------------------------
  # Cassette Replay Plug
  #
  # Reads recorded HTTP interactions from cassette JSON files and replays them.
  # Matches requests by method and URI path. This is injected into Assent's
  # HTTP pipeline via the :http_adapter config key.
  # ---------------------------------------------------------------------------

  defmodule CassettePlug do
    @moduledoc false

    @doc "Loads interactions from a cassette JSON file and returns a Plug module."
    def load(cassette_name) do
      path = Path.join("test/cassettes/oauth", "#{cassette_name}.json")
      json = File.read!(path)
      %{"interactions" => interactions} = Jason.decode!(json)
      {__MODULE__, interactions}
    end

    def init(interactions), do: interactions

    def call(conn, interactions) do
      uri = request_uri(conn)
      method = String.upcase(conn.method)

      case find_interaction(interactions, method, uri) do
        nil ->
          Plug.Conn.send_resp(conn, 404, Jason.encode!(%{
            "error" => "no_cassette_match",
            "method" => method,
            "uri" => uri,
            "available" => Enum.map(interactions, &{&1["request"]["method"], &1["request"]["uri"]})
          }))

        interaction ->
          response = interaction["response"]
          status = response["status"]

          body =
            case response["body_type"] do
              "json" -> Jason.encode!(response["body_json"])
              _ -> response["body"] || ""
            end

          headers =
            Enum.flat_map(response["headers"] || %{}, fn {key, values} ->
              Enum.map(values, &{key, &1})
            end)

          conn =
            Enum.reduce(headers, conn, fn {key, value}, c ->
              Plug.Conn.put_resp_header(c, key, value)
            end)

          Plug.Conn.send_resp(conn, status, body)
      end
    end

    defp request_uri(conn) do
      %URI{
        scheme: to_string(conn.scheme),
        host: conn.host,
        port: conn.port,
        path: conn.request_path
      }
      |> URI.to_string()
    end

    defp find_interaction(interactions, method, uri) do
      Enum.find(interactions, fn interaction ->
        req = interaction["request"]
        req["method"] == method and uri_matches?(req["uri"], uri)
      end)
    end

    # Match if the cassette URI path is contained in the request URI
    defp uri_matches?(cassette_uri, request_uri) do
      cassette_path = URI.parse(cassette_uri).path
      request_path = URI.parse(request_uri).path
      cassette_path == request_path
    end
  end

  # ---------------------------------------------------------------------------
  # Provider Modules — use real Assent.Strategy.OAuth2 with cassette replay
  # ---------------------------------------------------------------------------

  defmodule GoogleAdsProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      {plug_mod, plug_opts} = MetricFlowTest.OAuthStub.CassettePlug.load("google_ads_callback")

      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "http://localhost:4002/integrations/oauth/callback/google_ads",
        base_url: "https://oauth2.googleapis.com",
        token_url: "https://oauth2.googleapis.com/token",
        user_url: "https://www.googleapis.com/oauth2/v3/userinfo",
        http_adapter: {Assent.HTTPAdapter.Req, [plug: {plug_mod, plug_opts}]}
      ]
    end

    @impl true
    def strategy, do: Assent.Strategy.OAuth2

    @impl true
    def normalize_user(%{"sub" => sub} = data) when is_binary(sub) do
      {:ok,
       %{
         provider_user_id: sub,
         email: Map.get(data, "email"),
         name: Map.get(data, "name"),
         username: Map.get(data, "email"),
         avatar_url: Map.get(data, "picture")
       }}
    end

    def normalize_user(data) do
      {:ok,
       %{
         provider_user_id: Map.get(data, "sub", "unknown"),
         email: Map.get(data, "email"),
         name: Map.get(data, "name"),
         username: Map.get(data, "email"),
         avatar_url: nil
       }}
    end
  end

  defmodule FacebookAdsProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      {plug_mod, plug_opts} = MetricFlowTest.OAuthStub.CassettePlug.load("facebook_ads_callback")

      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "http://localhost:4002/integrations/oauth/callback/facebook_ads",
        base_url: "https://graph.facebook.com",
        token_url: "https://graph.facebook.com/v22.0/oauth/access_token",
        user_url: "https://graph.facebook.com/me",
        http_adapter: {Assent.HTTPAdapter.Req, [plug: {plug_mod, plug_opts}]}
      ]
    end

    @impl true
    def strategy, do: Assent.Strategy.OAuth2

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

    def normalize_user(data) do
      {:ok,
       %{
         provider_user_id: Map.get(data, "sub", "unknown"),
         email: Map.get(data, "email"),
         name: Map.get(data, "name"),
         username: Map.get(data, "email"),
         avatar_url: nil
       }}
    end
  end

  defmodule QuickBooksProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      {plug_mod, plug_opts} = MetricFlowTest.OAuthStub.CassettePlug.load("quickbooks_callback")

      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "http://localhost:4002/integrations/oauth/callback/quickbooks",
        base_url: "https://oauth.platform.intuit.com",
        token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer",
        auth_method: :client_secret_basic,
        http_adapter: {Assent.HTTPAdapter.Req, [plug: {plug_mod, plug_opts}]}
      ]
    end

    @impl true
    def strategy, do: Assent.Strategy.OAuth2

    @impl true
    def normalize_user(data) do
      {:ok,
       %{
         provider_user_id: Map.get(data, "sub", "quickbooks-user"),
         email: Map.get(data, "email"),
         name: Map.get(data, "name"),
         username: Map.get(data, "email"),
         avatar_url: nil
       }}
    end
  end
end
