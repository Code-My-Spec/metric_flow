defmodule MetricFlow.DataSync.DataProviders.QuickBooksTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import ReqCassette

  alias MetricFlow.DataSync.DataProviders.QuickBooks
  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  defp past_expires_at do
    DateTime.add(DateTime.utc_now(), -3600, :second)
  end

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :quickbooks,
      access_token: "qb_valid_access_token",
      refresh_token: "qb_refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: %{"realm_id" => "1234567890", "income_account_id" => "42"},
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 2,
      provider: :quickbooks,
      access_token: "qb_expired_access_token",
      refresh_token: "qb_expired_refresh_token",
      expires_at: past_expires_at(),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: %{"realm_id" => "1234567890", "income_account_id" => "42"},
      user_id: 1
    )
  end

  defp integration_without_realm_id do
    struct!(Integration,
      id: 3,
      provider: :quickbooks,
      access_token: "qb_valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: %{"income_account_id" => "42"},
      user_id: 1
    )
  end

  defp integration_without_account_id do
    struct!(Integration,
      id: 4,
      provider: :quickbooks,
      access_token: "qb_valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["com.intuit.quickbooks.accounting"],
      provider_metadata: %{"realm_id" => "1234567890"},
      user_id: 1
    )
  end

  # ---------------------------------------------------------------------------
  # API response fixtures — TransactionList report
  # ---------------------------------------------------------------------------

  # TransactionList response matching the real QBO API format.
  # Two positive transactions on Jan 15, one negative on Jan 20.
  defp transaction_list_response do
    Jason.encode!(%{
      "Header" => %{
        "ReportName" => "TransactionList",
        "StartPeriod" => "2026-01-15",
        "EndPeriod" => "2026-01-20",
        "Currency" => "USD"
      },
      "Columns" => %{
        "Column" => [
          %{"ColTitle" => "Date", "ColType" => "tx_date"},
          %{"ColTitle" => "Transaction Type", "ColType" => "txn_type"},
          %{"ColTitle" => "Num", "ColType" => "doc_num"},
          %{"ColTitle" => "Posting", "ColType" => "is_no_post"},
          %{"ColTitle" => "Name", "ColType" => "name"},
          %{"ColTitle" => "Memo/Description", "ColType" => "memo"},
          %{"ColTitle" => "Account", "ColType" => "account_name"},
          %{"ColTitle" => "Split", "ColType" => "other_account"},
          %{"ColTitle" => "Amount", "ColType" => "subt_nat_amount"}
        ]
      },
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{
              "ColData" => [
                %{"id" => "1", "value" => "Test Customer"},
                %{"value" => ""}, %{"value" => ""}, %{"value" => ""},
                %{"value" => ""}, %{"value" => ""}, %{"value" => ""},
                %{"value" => ""}, %{"value" => ""}
              ]
            },
            "Rows" => %{
              "Row" => [
                %{
                  "ColData" => [
                    %{"value" => "2026-01-15"}, %{"value" => "Invoice"},
                    %{"value" => "1001"}, %{"value" => "Yes"},
                    %{"value" => "Test Customer"}, %{"value" => "Widget sale"},
                    %{"value" => "Accounts Receivable"}, %{"value" => "-Split-"},
                    %{"value" => "500.00"}
                  ],
                  "type" => "Data"
                },
                %{
                  "ColData" => [
                    %{"value" => "2026-01-15"}, %{"value" => "Invoice"},
                    %{"value" => "1002"}, %{"value" => "Yes"},
                    %{"value" => "Another Customer"}, %{"value" => "Service"},
                    %{"value" => "Accounts Receivable"}, %{"value" => "-Split-"},
                    %{"value" => "250.00"}
                  ],
                  "type" => "Data"
                },
                %{
                  "ColData" => [
                    %{"value" => "2026-01-20"}, %{"value" => "Expense"},
                    %{"value" => ""}, %{"value" => "Yes"},
                    %{"value" => ""}, %{"value" => "Adjustment"},
                    %{"value" => "Checking"}, %{"value" => "Dues"},
                    %{"value" => "-100.00"}
                  ],
                  "type" => "Data"
                }
              ]
            },
            "Summary" => %{
              "ColData" => [
                %{"value" => "Total for Test Customer"},
                %{"value" => ""}, %{"value" => ""}, %{"value" => ""},
                %{"value" => ""}, %{"value" => ""}, %{"value" => ""},
                %{"value" => ""}, %{"value" => "650.00"}
              ]
            },
            "type" => "Section"
          }
        ]
      }
    })
  end

  defp empty_transaction_list_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "TransactionList"},
      "Columns" => %{
        "Column" => [
          %{"ColTitle" => "Date", "ColType" => "tx_date"},
          %{"ColTitle" => "Transaction Type", "ColType" => "txn_type"},
          %{"ColTitle" => "Num", "ColType" => "doc_num"},
          %{"ColTitle" => "Posting", "ColType" => "is_no_post"},
          %{"ColTitle" => "Name", "ColType" => "name"},
          %{"ColTitle" => "Memo/Description", "ColType" => "memo"},
          %{"ColTitle" => "Account", "ColType" => "account_name"},
          %{"ColTitle" => "Split", "ColType" => "other_account"},
          %{"ColTitle" => "Amount", "ColType" => "subt_nat_amount"}
        ]
      },
      "Rows" => %{"Row" => []}
    })
  end

  # ---------------------------------------------------------------------------
  # Test plug helpers
  # ---------------------------------------------------------------------------

  defp capture_request_plug(test_pid, response_body) do
    fn conn ->
      send(test_pid, {:request, conn})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, response_body)
    end
  end

  defp error_plug(status, body \\ "{}") do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  # ---------------------------------------------------------------------------
  # describe provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :quickbooks" do
      assert QuickBooks.provider() == :quickbooks
    end
  end

  # ---------------------------------------------------------------------------
  # describe required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns accounting scope" do
      assert QuickBooks.required_scopes() == ["com.intuit.quickbooks.accounting"]
    end
  end

  # ---------------------------------------------------------------------------
  # describe fetch_metrics/2
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2" do
    test "returns ok tuple with list of daily credit/debit metrics" do
      plug = capture_request_plug(self(), transaction_list_response())

      result =
        capture_log(fn ->
          assert {:ok, metrics} =
                   QuickBooks.fetch_metrics(valid_integration(),
                     http_plug: plug,
                     date_range: {~D[2026-01-15], ~D[2026-01-20]}
                   )

          # 6 days × 2 metrics (credits + debits) = 12
          assert length(metrics) == 12

          credit_metrics = Enum.filter(metrics, &(&1.metric_name == "QUICKBOOKS_ACCOUNT_DAILY_CREDITS"))
          debit_metrics = Enum.filter(metrics, &(&1.metric_name == "QUICKBOOKS_ACCOUNT_DAILY_DEBITS"))

          assert length(credit_metrics) == 6
          assert length(debit_metrics) == 6

          send(self(), {:metrics, metrics})
        end)

      assert_receive {:metrics, _metrics}
    end

    test "sets provider to :quickbooks for all metrics" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        for metric <- metrics do
          assert metric.provider == :quickbooks
        end
      end)
    end

    test "produces QUICKBOOKS_ACCOUNT_DAILY_CREDITS and QUICKBOOKS_ACCOUNT_DAILY_DEBITS metrics" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        metric_names = metrics |> Enum.map(& &1.metric_name) |> Enum.uniq() |> Enum.sort()
        assert metric_names == ["QUICKBOOKS_ACCOUNT_DAILY_CREDITS", "QUICKBOOKS_ACCOUNT_DAILY_DEBITS"]
      end)
    end

    test "aggregates credits by date from TransactionList data rows" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        jan15_credits =
          Enum.find(metrics, fn m ->
            m.metric_name == "QUICKBOOKS_ACCOUNT_DAILY_CREDITS" and
              DateTime.to_date(m.recorded_at) == ~D[2026-01-15]
          end)

        # Two credit entries on Jan 15: 500.00 + 250.00 = 750.00
        assert jan15_credits.value == 750.0
      end)
    end

    test "aggregates debits by date from TransactionList data rows" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        jan20_debits =
          Enum.find(metrics, fn m ->
            m.metric_name == "QUICKBOOKS_ACCOUNT_DAILY_DEBITS" and
              DateTime.to_date(m.recorded_at) == ~D[2026-01-20]
          end)

        # One debit entry on Jan 20: 100.00
        assert jan20_debits.value == 100.0
      end)
    end

    test "backfills zero-value records for days with no transactions" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        # Jan 16 has no transactions in the fixture
        jan16_credits =
          Enum.find(metrics, fn m ->
            m.metric_name == "QUICKBOOKS_ACCOUNT_DAILY_CREDITS" and
              DateTime.to_date(m.recorded_at) == ~D[2026-01-16]
          end)

        jan16_debits =
          Enum.find(metrics, fn m ->
            m.metric_name == "QUICKBOOKS_ACCOUNT_DAILY_DEBITS" and
              DateTime.to_date(m.recorded_at) == ~D[2026-01-16]
          end)

        assert jan16_credits.value == 0.0
        assert jan16_debits.value == 0.0
      end)
    end

    test "sets metric_type to financial" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        for metric <- metrics do
          assert metric.metric_type == "financial"
        end
      end)
    end

    test "sets recorded_at to the date of the metric at midnight UTC" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-15]}
          )

        for metric <- metrics do
          assert %DateTime{} = metric.recorded_at
          assert metric.recorded_at.hour == 0
          assert metric.recorded_at.minute == 0
          assert metric.recorded_at.second == 0
        end
      end)
    end

    test "includes account_id in metadata" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-15]}
          )

        for metric <- metrics do
          assert metric.metadata.account_id == "42"
        end
      end)
    end

    test "extracts access_token from integration struct" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(), http_plug: plug, date_range: {~D[2026-01-15], ~D[2026-01-15]})
      end)

      assert_receive {:request, conn}
      auth_header = Plug.Conn.get_req_header(conn, "authorization")
      assert auth_header == ["Bearer qb_valid_access_token"]
    end

    test "includes Accept header with application/json" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(), http_plug: plug, date_range: {~D[2026-01-15], ~D[2026-01-15]})
      end)

      assert_receive {:request, conn}
      accept_header = Plug.Conn.get_req_header(conn, "accept")
      assert accept_header == ["application/json"]
    end

    test "builds correct TransactionList API URL with realm_id" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "9876543210",
          http_plug: plug,
          date_range: {~D[2026-01-15], ~D[2026-01-15]}
        )
      end)

      assert_receive {:request, conn}
      assert conn.request_path =~ "/9876543210/reports/TransactionList"
    end

    test "includes account filter in query parameters" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          http_plug: plug,
          date_range: {~D[2026-01-15], ~D[2026-01-15]}
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "account=42")
    end

    test "sets start_date and end_date query parameters from date_range option" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          http_plug: plug,
          date_range: {~D[2026-01-01], ~D[2026-01-31]}
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "start_date=2026-01-01")
      assert String.contains?(conn.query_string, "end_date=2026-01-31")
    end

    test "defaults to last 548 days when date_range not provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())
      today = Date.utc_today()
      expected_start = Date.add(today, -548)

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "end_date=#{Date.to_iso8601(today)}")
      assert String.contains?(conn.query_string, "start_date=#{Date.to_iso8601(expected_start)}")
    end

    test "formats dates as YYYY-MM-DD in query parameters" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          http_plug: plug,
          date_range: {~D[2026-01-01], ~D[2026-01-31]}
        )
      end)

      assert_receive {:request, conn}
      assert Regex.match?(~r/start_date=\d{4}-\d{2}-\d{2}/, conn.query_string)
      assert Regex.match?(~r/end_date=\d{4}-\d{2}-\d{2}/, conn.query_string)
    end

    test "validates date_range start is before end date" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, transaction_list_response())
      end

      result =
        capture_log(fn ->
          assert {:error, :invalid_date_range} =
                   QuickBooks.fetch_metrics(valid_integration(),
                     http_plug: plug,
                     date_range: {~D[2026-02-01], ~D[2026-01-01]}
                   )
        end)
    end

    test "sets realm_id from provider_metadata when not in options" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          http_plug: plug,
          date_range: {~D[2026-01-15], ~D[2026-01-15]}
        )
      end)

      assert_receive {:request, conn}
      assert conn.request_path =~ "/1234567890/reports/TransactionList"
    end

    test "sets realm_id from options when provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "OVERRIDE_REALM",
          http_plug: plug,
          date_range: {~D[2026-01-15], ~D[2026-01-15]}
        )
      end)

      assert_receive {:request, conn}
      assert conn.request_path =~ "/OVERRIDE_REALM/reports/TransactionList"
    end

    test "sets account_id from options when provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          account_id: "99",
          http_plug: plug,
          date_range: {~D[2026-01-15], ~D[2026-01-15]}
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "account=99")
    end

    test "returns error when realm_id is missing from both options and metadata" do
      capture_log(fn ->
        plug = fn conn -> Plug.Conn.send_resp(conn, 200, transaction_list_response()) end

        assert {:error, :missing_realm_id} =
                 QuickBooks.fetch_metrics(integration_without_realm_id(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "returns error when account_id is missing from both options and metadata" do
      capture_log(fn ->
        plug = fn conn -> Plug.Conn.send_resp(conn, 200, transaction_list_response()) end

        assert {:error, :missing_account_id} =
                 QuickBooks.fetch_metrics(integration_without_account_id(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "returns error :unauthorized when token is expired" do
      plug = fn conn -> Plug.Conn.send_resp(conn, 200, transaction_list_response()) end

      assert {:error, :unauthorized} =
               QuickBooks.fetch_metrics(expired_integration(),
                 http_plug: plug,
                 date_range: {~D[2026-01-15], ~D[2026-01-15]}
               )
    end

    test "handles empty Rows with zero values for all days" do
      plug = capture_request_plug(self(), empty_transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-17]}
          )

        # 3 days × 2 metrics = 6
        assert length(metrics) == 6

        for metric <- metrics do
          assert metric.value == 0.0
        end
      end)
    end

    test "handles malformed JSON response with error" do
      plug = error_plug(200, "not json at all{{{")

      capture_log(fn ->
        assert_raise Jason.DecodeError, fn ->
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-15]}
          )
        end
      end)
    end

    test "returns error :unauthorized for 401 response" do
      plug = error_plug(401, ~s({"Fault":{"Error":[{"Message":"message=AuthenticationFailed"}]}}))

      capture_log(fn ->
        assert {:error, :unauthorized} =
                 QuickBooks.fetch_metrics(valid_integration(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "returns error :insufficient_permissions for 403 response" do
      plug = error_plug(403, ~s({"Fault":{"Error":[{"Message":"Forbidden"}]}}))

      capture_log(fn ->
        assert {:error, :insufficient_permissions} =
                 QuickBooks.fetch_metrics(valid_integration(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "returns error :company_not_found for 404 response" do
      plug = error_plug(404)

      capture_log(fn ->
        assert {:error, :company_not_found} =
                 QuickBooks.fetch_metrics(valid_integration(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "returns error :bad_request for 400 response" do
      plug = error_plug(400, ~s({"Fault":{"Error":[{"Message":"Bad Request"}]}}))

      capture_log(fn ->
        assert {:error, :bad_request} =
                 QuickBooks.fetch_metrics(valid_integration(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "handles network errors gracefully with error tuple" do
      plug = fn _conn -> raise Req.TransportError, reason: :econnrefused end

      capture_log(fn ->
        assert {:error, {:network_error, :econnrefused}} =
                 QuickBooks.fetch_metrics(valid_integration(),
                   http_plug: plug,
                   date_range: {~D[2026-01-15], ~D[2026-01-15]}
                 )
      end)
    end

    test "converts metric values to float" do
      plug = capture_request_plug(self(), transaction_list_response())

      capture_log(fn ->
        {:ok, metrics} =
          QuickBooks.fetch_metrics(valid_integration(),
            http_plug: plug,
            date_range: {~D[2026-01-15], ~D[2026-01-20]}
          )

        for metric <- metrics do
          assert is_float(metric.value)
        end
      end)
    end

    test "includes account filter in query string" do
      test_pid = self()
      plug = capture_request_plug(test_pid, transaction_list_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          http_plug: plug,
          date_range: {~D[2026-01-15], ~D[2026-01-15]}
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "account=42")
    end
  end

  # ---------------------------------------------------------------------------
  # Cassette integration tests — real QuickBooks API traffic
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2 with cassette" do
    @describetag :integration

    import MetricFlowTest.CassetteFixtures

    setup do
      case quickbooks_integration() do
        nil -> {:ok, skip: true}
        integration -> {:ok, integration: integration}
      end
    end

    test "fetches real financial metrics from QuickBooks API", context do
      if context[:skip], do: flunk("QUICKBOOKS_TEST_REALM_ID not set in .env.test")

      capture_log(fn ->
        with_cassette "quickbooks_fetch_metrics", cassette_opts("quickbooks_fetch_metrics"), fn plug ->
          assert {:ok, metrics} =
                   QuickBooks.fetch_metrics(context.integration,
                     http_plug: plug,
                     date_range: default_date_range()
                   )

          assert is_list(metrics)

          for metric <- metrics do
            assert metric.provider == :quickbooks
            assert is_binary(metric.metric_type)
            assert is_binary(metric.metric_name)
            assert is_number(metric.value)
            assert %DateTime{} = metric.recorded_at
            assert is_map(metric.metadata)
          end
        end
      end)
    end

    test "returns structured error for unauthorized request", context do
      if context[:skip], do: flunk("QUICKBOOKS_TEST_REALM_ID not set in .env.test")

      capture_log(fn ->
        with_cassette "quickbooks_unauthorized", cassette_opts("quickbooks_unauthorized"), fn plug ->
          bad_token = %{context.integration | access_token: "invalid-token"}

          assert {:error, reason} =
                   QuickBooks.fetch_metrics(bad_token,
                     http_plug: plug,
                     date_range: default_date_range()
                   )

          assert reason in [:unauthorized, :insufficient_permissions, :company_not_found]
        end
      end)
    end
  end
end
