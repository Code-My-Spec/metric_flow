defmodule MetricFlow.Integrations.StaleTokenRefreshTest do
  # An access token lasts an hour. A connection with a refresh token must keep
  # working after that, not ask the user to reconnect.
  use MetricFlowTest.DataCase, async: false

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Integrations

  defmodule RefreshingProvider do
    def config, do: [client_id: "id", client_secret: "secret", redirect_uri: "https://x/cb"]
    def strategy, do: __MODULE__
    def normalize_user(user), do: {:ok, user}

    def refresh_access_token(_config, %{"refresh_token" => rt}) when is_binary(rt),
      do: {:ok, %{"access_token" => "refreshed-access-token", "expires_in" => 3600}}
  end

  setup do
    original = Application.get_env(:metric_flow, :oauth_providers)

    Application.put_env(:metric_flow, :oauth_providers, %{
      facebook_ads: RefreshingProvider
    })

    on_exit(fn ->
      if original,
        do: Application.put_env(:metric_flow, :oauth_providers, original),
        else: Application.delete_env(:metric_flow, :oauth_providers)
    end)

    user = user_fixture()
    %{user: user, scope: user_scope_fixture(user)}
  end

  test "listing accounts refreshes a stale access token first", %{user: user, scope: scope} do
    integration_fixture(user, %{
      provider: :facebook_ads,
      expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
      refresh_token: "stub-refresh-token"
    })

    test_pid = self()

    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      send(test_pid, {:token_used, conn.query_params["access_token"]})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => []}))
    end

    assert {:ok, []} = Integrations.list_facebook_ads_accounts(scope, http_plug: plug)
    assert_received {:token_used, "refreshed-access-token"}

    {:ok, stored} = Integrations.get_integration(scope, :facebook_ads)
    refute MetricFlow.Integrations.Integration.expired?(stored)
  end

  test "without a refresh token it reports :token_expired", %{user: user, scope: scope} do
    integration_fixture(user, %{
      provider: :facebook_ads,
      expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
      refresh_token: nil
    })

    assert {:error, :token_expired} = Integrations.list_facebook_ads_accounts(scope)
  end
end
