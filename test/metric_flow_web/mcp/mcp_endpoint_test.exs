defmodule MetricFlowWeb.MCPEndpointTest do
  use MetricFlowTest.ConnCase, async: false

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.OauthFixtures

  import MetricFlowTest.AgenciesFixtures,
    only: [account_fixture: 1, account_with_member_fixture: 2]

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo

  defp rpc(conn, path, token, body, session \\ nil) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> then(&if session, do: put_req_header(&1, "mcp-session-id", session), else: &1)
    |> post(path, Jason.encode!(body))
  end

  defp decode(conn) do
    body = conn.resp_body

    case Jason.decode(body) do
      {:ok, json} ->
        json

      _ ->
        # SSE framing: take the last `data:` line
        body
        |> String.split("\n")
        |> Enum.filter(&String.starts_with?(&1, "data:"))
        |> List.last()
        |> String.replace_prefix("data:", "")
        |> Jason.decode!()
    end
  end

  defp handshake(conn, path, token) do
    init =
      rpc(conn, path, token, %{
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: %{
          protocolVersion: "2025-06-18",
          capabilities: %{},
          clientInfo: %{name: "test", version: "1"}
        }
      })

    assert init.status == 200
    [session] = get_resp_header(init, "mcp-session-id")
    rpc(conn, path, token, %{jsonrpc: "2.0", method: "notifications/initialized"}, session)
    session
  end

  defp call_tool(conn, token, session, name, arguments) do
    conn
    |> rpc(
      "/mcp",
      token,
      %{
        jsonrpc: "2.0",
        id: System.unique_integer([:positive]),
        method: "tools/call",
        params: %{name: name, arguments: arguments}
      },
      session
    )
    |> decode()
    |> Map.fetch!("result")
  end

  defp text(result), do: result["content"] |> hd() |> Map.get("text")

  setup %{conn: conn} do
    user = user_fixture()
    own = originated_account_fixture(user.id)

    # An agency member reaches a client account through an AccountMember row
    # (what an agency access grant materializes).
    client = account_fixture(%{type: "client", name: "Client Co"})

    %AccountMember{}
    |> AccountMember.changeset(%{account_id: client.id, user_id: user.id, role: :account_manager})
    |> Repo.insert!()

    token = oauth_token_fixture(user).token
    %{user: user, own: own, client: client, token: token, session: handshake(conn, "/mcp", token)}
  end

  test "lists the account-aware tools", %{conn: conn, token: token, session: session} do
    list = rpc(conn, "/mcp", token, %{jsonrpc: "2.0", id: 2, method: "tools/list"}, session)
    tools = decode(list)["result"]["tools"]
    names = Enum.map(tools, & &1["name"])

    assert "list_accounts" in names
    assert "disconnect_product" in names
    status = Enum.find(tools, &(&1["name"] == "get_setup_status"))
    assert status["inputSchema"]["properties"]["account_id"]["type"] == "integer"
  end

  test "list_accounts shows own and agency client accounts with roles", %{
    conn: conn,
    token: token,
    session: session,
    own: own,
    client: client
  } do
    result = call_tool(conn, token, session, "list_accounts", %{})
    refute result["isError"]
    accounts = Jason.decode!(text(result))["accounts"]

    assert %{"role" => "owner"} = Enum.find(accounts, &(&1["id"] == own.id))

    assert %{"role" => "account_manager", "name" => "Client Co", "setup" => setup} =
             Enum.find(accounts, &(&1["id"] == client.id))

    assert setup =~ "Google: not connected"
  end

  test "get_setup_status acts on the named account, including an agency client", %{
    conn: conn,
    token: token,
    session: session,
    client: client
  } do
    result = call_tool(conn, token, session, "get_setup_status", %{account_id: client.id})
    refute result["isError"]
    assert [_, _, _] = Jason.decode!(text(result))["connections"]

    link =
      call_tool(conn, token, session, "get_connect_link", %{
        account_id: client.id,
        connection: "google"
      })

    assert text(link) =~ "account_id=#{client.id}"
  end

  test "account_id is required with several accounts; non-members are refused", %{
    conn: conn,
    token: token,
    session: session
  } do
    missing = call_tool(conn, token, session, "get_setup_status", %{})
    assert missing["isError"]
    assert text(missing) =~ "list_accounts"

    stranger = account_fixture(%{type: "client"})
    refused = call_tool(conn, token, session, "get_setup_status", %{account_id: stranger.id})
    assert refused["isError"]
    assert text(refused) =~ "not a member"
  end

  test "read-only members can check but not change setup", %{
    conn: conn,
    token: token,
    session: session,
    user: user
  } do
    read_only = account_with_member_fixture(user, :read_only)

    assert %{"isError" => false} =
             call_tool(conn, token, session, "get_setup_status", %{account_id: read_only.id})

    refused =
      call_tool(conn, token, session, "sync_now", %{
        account_id: read_only.id,
        product: "google_analytics"
      })

    assert refused["isError"]
    assert text(refused) =~ "read-only"
  end

  test "requests without a valid token are refused", %{conn: conn} do
    assert rpc(conn, "/mcp", "nope", %{jsonrpc: "2.0", id: 1, method: "ping"}).status == 401
  end
end
