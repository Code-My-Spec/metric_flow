defmodule MetricFlowWeb.Plugs.MCPAuthTest do
  use MetricFlowTest.ConnCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.OauthFixtures

  alias MetricFlowWeb.Plugs.MCPAuth

  defp run(conn), do: conn |> Map.put(:request_path, "/mcp") |> MCPAuth.call(MCPAuth.init([]))

  defp bearer(conn, token),
    do: Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)

  test "accepts a valid OAuth access token and assigns its user", %{conn: conn} do
    user = user_fixture()
    token = oauth_token_fixture(user)

    conn = conn |> bearer(token.token) |> run()
    refute conn.halted
    assert conn.assigns.mcp_user_id == user.id
  end

  test "rejects a revoked token", %{conn: conn} do
    token = oauth_token_fixture(user_fixture())
    {:ok, _} = ExOauth2Provider.AccessTokens.revoke(token, otp_app: :metric_flow)

    assert conn |> bearer(token.token) |> run() |> Map.get(:status) == 401
  end

  test "401s point the client at the protected-resource metadata", %{conn: conn} do
    for conn <- [run(conn), conn |> bearer("nope") |> run()] do
      assert conn.status == 401
      assert conn.halted
      [challenge] = Plug.Conn.get_resp_header(conn, "www-authenticate")
      base = MetricFlowWeb.Endpoint.url()
      assert challenge =~ ~s(Bearer realm="#{base}/mcp")
      assert challenge =~ ~s(resource_metadata="#{base}/.well-known/oauth-protected-resource/mcp")
    end
  end
end
