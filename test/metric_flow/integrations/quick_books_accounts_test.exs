defmodule MetricFlow.Integrations.QuickBooksAccountsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.QuickBooksAccounts

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :quickbooks,
      access_token: "qb_valid_access_token",
      refresh_token: "qb_refresh_token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: %{"realm_id" => "1234567890"},
      user_id: 1
    )
  end

  defp integration_without_realm_id do
    struct!(Integration,
      id: 2,
      provider: :quickbooks,
      access_token: "qb_valid_access_token",
      refresh_token: nil,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: %{"income_account_id" => "42"},
      user_id: 1
    )
  end

  defp integration_with_nil_metadata do
    struct!(Integration,
      id: 3,
      provider: :quickbooks,
      access_token: "qb_valid_access_token",
      refresh_token: nil,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: nil,
      user_id: 1
    )
  end

  # ---------------------------------------------------------------------------
  # API response fixtures
  # ---------------------------------------------------------------------------

  defp account_list_response do
    Jason.encode!(%{
      "QueryResponse" => %{
        "Account" => [
          %{
            "Id" => "42",
            "Name" => "Sales of Product Income",
            "FullyQualifiedName" => "Sales of Product Income",
            "AccountType" => "Income"
          },
          %{
            "Id" => "99",
            "Name" => "Services",
            "FullyQualifiedName" => "Services:Consulting",
            "AccountType" => "Income"
          }
        ],
        "startPosition" => 1,
        "maxResults" => 2
      },
      "time" => "2026-01-01T00:00:00.000-08:00"
    })
  end

  defp account_missing_fully_qualified_name_response do
    Jason.encode!(%{
      "QueryResponse" => %{
        "Account" => [
          %{
            "Id" => "77",
            "Name" => "Other Income",
            "AccountType" => "Income"
          }
        ]
      }
    })
  end

  defp account_missing_name_response do
    Jason.encode!(%{
      "QueryResponse" => %{
        "Account" => [
          %{
            "Id" => "55",
            "FullyQualifiedName" => "Mystery Account",
            "AccountType" => "Income"
          }
        ]
      }
    })
  end

  defp empty_query_response do
    Jason.encode!(%{
      "QueryResponse" => %{},
      "time" => "2026-01-01T00:00:00.000-08:00"
    })
  end

  defp missing_query_response_body do
    Jason.encode!(%{
      "time" => "2026-01-01T00:00:00.000-08:00"
    })
  end

  # ---------------------------------------------------------------------------
  # Test plug helpers
  # ---------------------------------------------------------------------------

  defp response_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  defp capture_request_plug(test_pid, response_body) do
    fn conn ->
      send(test_pid, {:request, conn})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, response_body)
    end
  end

  defp raising_plug(exception) do
    fn _conn -> raise exception end
  end

  # ---------------------------------------------------------------------------
  # describe list_income_accounts/2
  # ---------------------------------------------------------------------------

  describe "list_income_accounts/2" do
    test "returns {:ok, accounts} with a list of account maps on a 200 response with valid JSON body" do
      plug = response_plug(200, account_list_response())

      assert {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
      assert is_list(accounts)
      assert length(accounts) == 2
    end

    test "each returned account map has :id, :name, and :account keys" do
      plug = response_plug(200, account_list_response())

      {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      for account <- accounts do
        assert Map.has_key?(account, :id)
        assert Map.has_key?(account, :name)
        assert Map.has_key?(account, :account)
      end
    end

    test "extracts :id from the \"Id\" field as a string" do
      plug = response_plug(200, account_list_response())

      {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      first = Enum.find(accounts, &(&1.id == "42"))
      assert first.id == "42"
      assert is_binary(first.id)
    end

    test "extracts :name from the \"Name\" field" do
      plug = response_plug(200, account_list_response())

      {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      first = Enum.find(accounts, &(&1.id == "42"))
      assert first.name == "Sales of Product Income"
    end

    test "extracts :account from the \"FullyQualifiedName\" field" do
      plug = response_plug(200, account_list_response())

      {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      nested = Enum.find(accounts, &(&1.id == "99"))
      assert nested.account == "Services:Consulting"
    end

    test "falls back to \"Name\" for :account when \"FullyQualifiedName\" is absent" do
      plug = response_plug(200, account_missing_fully_qualified_name_response())

      {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      assert length(accounts) == 1
      [account] = accounts
      assert account.account == "Other Income"
    end

    test "defaults :name to \"Unknown Account\" when the \"Name\" field is absent" do
      plug = response_plug(200, account_missing_name_response())

      {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      assert length(accounts) == 1
      [account] = accounts
      assert account.name == "Unknown Account"
    end

    test "returns {:ok, []} when \"Account\" key is absent in the QueryResponse" do
      plug = response_plug(200, empty_query_response())

      assert {:ok, []} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:ok, []} when \"QueryResponse\" key is absent in the response body" do
      plug = response_plug(200, missing_query_response_body())

      assert {:ok, []} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:error, :missing_realm_id} when provider_metadata has no \"realm_id\" key" do
      assert {:error, :missing_realm_id} =
               QuickBooksAccounts.list_income_accounts(integration_without_realm_id())
    end

    test "returns {:error, :missing_realm_id} when provider_metadata is nil" do
      assert {:error, :missing_realm_id} =
               QuickBooksAccounts.list_income_accounts(integration_with_nil_metadata())
    end

    test "returns {:error, :unauthorized} on a 401 response" do
      plug = response_plug(401, ~s({"Fault":{"Error":[{"Message":"AuthenticationFailed"}]}}))

      assert {:error, :unauthorized} =
               QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:error, :api_disabled} on a 403 response" do
      plug = response_plug(403, ~s({"Fault":{"Error":[{"Message":"Forbidden"}]}}))

      capture_log(fn ->
        assert {:error, :api_disabled} =
                 QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :bad_request} on an unexpected HTTP status code" do
      plug = response_plug(500, ~s({"error":"internal server error"}))

      capture_log(fn ->
        assert {:error, :bad_request} =
                 QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :malformed_response} on a 200 response with a non-JSON binary body" do
      # When Req receives a non-JSON body with content-type application/json, it raises
      # a Jason.DecodeError during auto-decode. The plug must return text/plain content type
      # so Req passes the raw binary to our handle_response/1 clause.
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "this is not json{{{{")
      end

      assert {:error, :malformed_response} =
               QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
    end

    test "returns {:error, {:network_error, message}} when the HTTP request raises an exception" do
      plug = raising_plug(%RuntimeError{message: "connection refused"})

      capture_log(fn ->
        assert {:error, {:network_error, message}} =
                 QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

        assert is_binary(message)
      end)
    end

    test "accepts an :http_plug option for test injection without making real HTTP calls" do
      test_pid = self()
      plug = capture_request_plug(test_pid, account_list_response())

      QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)

      assert_receive {:request, _conn}
    end

    test "handles 200 response with binary JSON body by decoding before extracting accounts" do
      # The plug sends raw binary JSON; verify the module decodes it correctly
      plug = response_plug(200, account_list_response())

      assert {:ok, accounts} = QuickBooksAccounts.list_income_accounts(valid_integration(), http_plug: plug)
      assert length(accounts) == 2
      assert Enum.all?(accounts, &is_map/1)
    end
  end
end
