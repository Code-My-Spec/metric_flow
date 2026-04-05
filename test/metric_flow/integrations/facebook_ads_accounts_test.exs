defmodule MetricFlow.Integrations.FacebookAdsAccountsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.FacebookAdsAccounts
  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :facebook_ads,
      access_token: "EAABsbCS4IHABOC_valid_access_token",
      refresh_token: nil,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["ads_read", "ads_management"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  defp active_account do
    %{
      "account_id" => "123456789",
      "name" => "My Active Ad Account",
      "account_status" => 1
    }
  end

  defp inactive_account do
    %{
      "account_id" => "999888777",
      "name" => "Suspended Account",
      "account_status" => 2
    }
  end

  defp another_active_account do
    %{
      "account_id" => "555444333",
      "name" => "Second Active Account",
      "account_status" => 1
    }
  end

  defp account_without_name do
    %{
      "account_id" => "777111222",
      "account_status" => 1
    }
  end

  defp valid_response_body(accounts) do
    Jason.encode!(%{"data" => accounts})
  end

  defp build_stub_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  defp build_map_body_plug(status, body_map) do
    # Returns a pre-decoded map body (simulates Req auto-decoding JSON)
    fn conn ->
      encoded = Jason.encode!(body_map)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, encoded)
    end
  end

  # ---------------------------------------------------------------------------
  # list_accounts/2
  # ---------------------------------------------------------------------------

  describe "list_accounts/2" do
    test "returns {:ok, accounts} with a list of account maps on a 200 response with valid JSON body" do
      body = valid_response_body([active_account()])
      plug = build_stub_plug(200, body)

      assert {:ok, accounts} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert is_list(accounts)
      assert length(accounts) == 1
    end

    test "each returned account map has :id, :name, and :account keys" do
      body = valid_response_body([active_account()])
      plug = build_stub_plug(200, body)

      assert {:ok, [account]} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert Map.has_key?(account, :id)
      assert Map.has_key?(account, :name)
      assert Map.has_key?(account, :account)
    end

    test "extracts :id from the \"account_id\" field" do
      body = valid_response_body([active_account()])
      plug = build_stub_plug(200, body)

      assert {:ok, [account]} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert account.id == "123456789"
    end

    test "extracts :name from the \"name\" field" do
      body = valid_response_body([active_account()])
      plug = build_stub_plug(200, body)

      assert {:ok, [account]} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert account.name == "My Active Ad Account"
    end

    test "sets :account to \"Facebook Ads\" for all returned accounts" do
      body = valid_response_body([active_account(), another_active_account()])
      plug = build_stub_plug(200, body)

      assert {:ok, accounts} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert Enum.all?(accounts, fn a -> a.account == "Facebook Ads" end)
    end

    test "filters out accounts where \"account_status\" is not 1" do
      body = valid_response_body([inactive_account()])
      plug = build_stub_plug(200, body)

      assert {:ok, accounts} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert accounts == []
    end

    test "returns only active accounts when the response contains a mix of active and inactive accounts" do
      accounts = [active_account(), inactive_account(), another_active_account()]
      body = valid_response_body(accounts)
      plug = build_stub_plug(200, body)

      assert {:ok, result} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert length(result) == 2
      assert Enum.all?(result, fn a -> a.account == "Facebook Ads" end)
      ids = Enum.map(result, & &1.id)
      assert "123456789" in ids
      assert "555444333" in ids
      refute "999888777" in ids
    end

    test "returns {:ok, []} when \"data\" is present but empty" do
      body = valid_response_body([])
      plug = build_stub_plug(200, body)

      assert {:ok, []} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:ok, []} when the response body does not contain a \"data\" key" do
      body = Jason.encode!(%{"error" => "some_error"})
      plug = build_stub_plug(200, body)

      assert {:ok, []} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
    end

    test "defaults :name to \"Ad Account #{account_id}\" when the \"name\" field is absent" do
      body = valid_response_body([account_without_name()])
      plug = build_stub_plug(200, body)

      assert {:ok, [account]} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert account.id == "777111222"
      assert account.name == "Ad Account 777111222"
    end

    test "returns {:error, :unauthorized} on a 400 response" do
      plug = build_stub_plug(400, Jason.encode!(%{"error" => "bad request"}))

      assert {:error, :unauthorized} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:error, :unauthorized} on a 401 response" do
      plug = build_stub_plug(401, Jason.encode!(%{"error" => "unauthorized"}))

      assert {:error, :unauthorized} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:error, :api_disabled} on a 403 response" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "forbidden"}))

      capture_log(fn ->
        assert {:error, :api_disabled} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :bad_request} on an unexpected HTTP status code" do
      plug = build_stub_plug(500, Jason.encode!(%{"error" => "server error"}))

      capture_log(fn ->
        assert {:error, :bad_request} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, {:network_error, message}} when the HTTP request raises an exception" do
      raising_plug = fn _conn ->
        raise "simulated network failure"
      end

      capture_log(fn ->
        assert {:error, {:network_error, message}} =
                 FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: raising_plug)

        assert is_binary(message)
        assert String.contains?(message, "simulated network failure")
      end)
    end

    test "accepts an :http_plug option for test injection without making real HTTP calls" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, :plug_called)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, valid_response_body([active_account()]))
      end

      FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)

      assert_received :plug_called
    end

    test "handles 200 response with binary JSON body by decoding before extracting accounts" do
      # The binary body path is exercised when Req does not auto-decode JSON.
      # We simulate this by returning raw JSON bytes as the body.
      binary_body = valid_response_body([active_account()])

      plug = fn conn ->
        # Send as text/plain to prevent Req from auto-decoding, keeping body as binary
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, binary_body)
      end

      assert {:ok, accounts} = FacebookAdsAccounts.list_accounts(valid_integration(), http_plug: plug)
      assert length(accounts) == 1
      assert hd(accounts).id == "123456789"
    end
  end
end
