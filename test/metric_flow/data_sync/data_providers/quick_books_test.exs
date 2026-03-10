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
      provider_metadata: %{"realm_id" => "1234567890"},
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
      provider_metadata: %{"realm_id" => "1234567890"},
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
      provider_metadata: %{},
      user_id: 1
    )
  end

  # ---------------------------------------------------------------------------
  # API response fixtures
  # ---------------------------------------------------------------------------

  defp profit_and_loss_response do
    Jason.encode!(%{
      "Header" => %{
        "ReportName" => "ProfitAndLoss",
        "StartPeriod" => "2026-01-01",
        "EndPeriod" => "2026-01-31"
      },
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{"ColData" => [%{"value" => "Income"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "ColData" => [
                    %{"value" => "Services Revenue", "id" => "1"},
                    %{"value" => "50000.00"}
                  ],
                  "type" => "Data"
                },
                %{
                  "ColData" => [
                    %{"value" => "Product Sales", "id" => "2"},
                    %{"value" => "30000.00"}
                  ],
                  "type" => "Data"
                }
              ]
            },
            "Summary" => %{
              "ColData" => [%{"value" => "Total Income"}, %{"value" => "80000.00"}]
            },
            "type" => "Section",
            "group" => "Income"
          },
          %{
            "Header" => %{"ColData" => [%{"value" => "Cost of Goods Sold"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "ColData" => [
                    %{"value" => "Cost of Goods Sold", "id" => "10"},
                    %{"value" => "20000.00"}
                  ],
                  "type" => "Data"
                }
              ]
            },
            "Summary" => %{
              "ColData" => [%{"value" => "Total Cost of Goods Sold"}, %{"value" => "20000.00"}]
            },
            "type" => "Section",
            "group" => "COGS"
          },
          %{
            "Header" => %{"ColData" => [%{"value" => "Expenses"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "ColData" => [
                    %{"value" => "Rent", "id" => "20"},
                    %{"value" => "5000.00"}
                  ],
                  "type" => "Data"
                },
                %{
                  "ColData" => [
                    %{"value" => "Salaries", "id" => "21"},
                    %{"value" => "25000.00"}
                  ],
                  "type" => "Data"
                }
              ]
            },
            "Summary" => %{
              "ColData" => [%{"value" => "Total Expenses"}, %{"value" => "30000.00"}]
            },
            "type" => "Section",
            "group" => "Expenses"
          },
          %{
            "Summary" => %{
              "ColData" => [%{"value" => "Net Income"}, %{"value" => "30000.00"}]
            },
            "type" => "Section",
            "group" => "NetIncome"
          }
        ]
      }
    })
  end

  defp balance_sheet_response do
    Jason.encode!(%{
      "Header" => %{
        "ReportName" => "BalanceSheet",
        "StartPeriod" => "2026-01-01",
        "EndPeriod" => "2026-01-31"
      },
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{"ColData" => [%{"value" => "Assets"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "Header" => %{
                    "ColData" => [%{"value" => "Current Assets"}, %{"value" => ""}]
                  },
                  "Rows" => %{
                    "Row" => [
                      %{
                        "Header" => %{
                          "ColData" => [%{"value" => "Bank Accounts"}, %{"value" => ""}]
                        },
                        "Rows" => %{
                          "Row" => [
                            %{
                              "ColData" => [
                                %{"value" => "Checking", "id" => "35"},
                                %{"value" => "15000.00"}
                              ],
                              "type" => "Data"
                            }
                          ]
                        },
                        "Summary" => %{
                          "ColData" => [
                            %{"value" => "Total Bank Accounts"},
                            %{"value" => "15000.00"}
                          ]
                        },
                        "type" => "Section",
                        "group" => "Bank"
                      },
                      %{
                        "Header" => %{
                          "ColData" => [%{"value" => "Accounts Receivable"}, %{"value" => ""}]
                        },
                        "Rows" => %{
                          "Row" => [
                            %{
                              "ColData" => [
                                %{"value" => "Accounts Receivable (A/R)", "id" => "40"},
                                %{"value" => "12000.00"}
                              ],
                              "type" => "Data"
                            }
                          ]
                        },
                        "Summary" => %{
                          "ColData" => [
                            %{"value" => "Total Accounts Receivable"},
                            %{"value" => "12000.00"}
                          ]
                        },
                        "type" => "Section",
                        "group" => "AR"
                      }
                    ]
                  },
                  "type" => "Section",
                  "group" => "CurrentAssets"
                }
              ]
            },
            "type" => "Section",
            "group" => "TotalAssets"
          },
          %{
            "Header" => %{"ColData" => [%{"value" => "Liabilities"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "Header" => %{
                    "ColData" => [%{"value" => "Current Liabilities"}, %{"value" => ""}]
                  },
                  "Rows" => %{
                    "Row" => [
                      %{
                        "Header" => %{
                          "ColData" => [%{"value" => "Accounts Payable"}, %{"value" => ""}]
                        },
                        "Rows" => %{
                          "Row" => [
                            %{
                              "ColData" => [
                                %{"value" => "Accounts Payable (A/P)", "id" => "50"},
                                %{"value" => "8000.00"}
                              ],
                              "type" => "Data"
                            }
                          ]
                        },
                        "Summary" => %{
                          "ColData" => [
                            %{"value" => "Total Accounts Payable"},
                            %{"value" => "8000.00"}
                          ]
                        },
                        "type" => "Section",
                        "group" => "AP"
                      }
                    ]
                  },
                  "type" => "Section",
                  "group" => "CurrentLiabilities"
                }
              ]
            },
            "type" => "Section",
            "group" => "TotalLiabilities"
          }
        ]
      }
    })
  end

  # P&L response with no Income section — exercises the missing-section fallback paths.
  defp profit_and_loss_no_income_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "ProfitAndLoss"},
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{"ColData" => [%{"value" => "Expenses"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "ColData" => [%{"value" => "Office Supplies", "id" => "99"}, %{"value" => "500.00"}],
                  "type" => "Data"
                }
              ]
            },
            "Summary" => %{
              "ColData" => [%{"value" => "Total Expenses"}, %{"value" => "500.00"}]
            },
            "type" => "Section",
            "group" => "Expenses"
          }
        ]
      }
    })
  end

  # P&L with no Expenses section.
  defp profit_and_loss_no_expenses_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "ProfitAndLoss"},
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{"ColData" => [%{"value" => "Income"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "ColData" => [%{"value" => "Services", "id" => "1"}, %{"value" => "10000.00"}],
                  "type" => "Data"
                }
              ]
            },
            "Summary" => %{
              "ColData" => [%{"value" => "Total Income"}, %{"value" => "10000.00"}]
            },
            "type" => "Section",
            "group" => "Income"
          }
        ]
      }
    })
  end

  # Empty Rows arrays for both reports.
  defp empty_profit_and_loss_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "ProfitAndLoss"},
      "Rows" => %{"Row" => []}
    })
  end

  defp empty_balance_sheet_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "BalanceSheet"},
      "Rows" => %{"Row" => []}
    })
  end

  # Balance sheet with no AR, AP, or cash sections.
  defp balance_sheet_no_ar_ap_cash_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "BalanceSheet"},
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{"ColData" => [%{"value" => "Equity"}, %{"value" => ""}]},
            "Rows" => %{"Row" => []},
            "type" => "Section",
            "group" => "Equity"
          }
        ]
      }
    })
  end

  # Balance sheet with HomeCurrencyAmount present in ColData entries.
  defp balance_sheet_multi_currency_response do
    Jason.encode!(%{
      "Header" => %{"ReportName" => "BalanceSheet"},
      "Rows" => %{
        "Row" => [
          %{
            "Header" => %{"ColData" => [%{"value" => "Assets"}, %{"value" => ""}]},
            "Rows" => %{
              "Row" => [
                %{
                  "Header" => %{
                    "ColData" => [%{"value" => "Current Assets"}, %{"value" => ""}]
                  },
                  "Rows" => %{
                    "Row" => [
                      %{
                        "Header" => %{
                          "ColData" => [%{"value" => "Bank Accounts"}, %{"value" => ""}]
                        },
                        "Rows" => %{
                          "Row" => [
                            %{
                              "ColData" => [
                                %{"value" => "Foreign Account", "id" => "70"},
                                %{"value" => "9000.00", "homeCurrencyAmount" => "8500.00"}
                              ],
                              "type" => "Data"
                            }
                          ]
                        },
                        "Summary" => %{
                          "ColData" => [
                            %{"value" => "Total Bank Accounts"},
                            %{"value" => "9000.00", "homeCurrencyAmount" => "8500.00"}
                          ]
                        },
                        "type" => "Section",
                        "group" => "Bank"
                      }
                    ]
                  },
                  "type" => "Section",
                  "group" => "CurrentAssets"
                }
              ]
            },
            "type" => "Section",
            "group" => "TotalAssets"
          }
        ]
      }
    })
  end

  # ---------------------------------------------------------------------------
  # Plug helpers
  # ---------------------------------------------------------------------------

  # Returns a simple Plug that always responds with `status` and `body`.
  defp build_stub_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  # Agent state transition used by build_sequential_plug/2.
  # Returns {body_to_serve, next_state} where the state is either
  # {:first, first_body, second_body} on the first call or :rest thereafter.
  defp sequential_next({:first, first_body, _second_body}), do: {first_body, :rest}
  defp sequential_next(:rest), do: {:rest_body, :rest}

  # Returns a sequential Plug that serves `first_body` on the first request
  # and `second_body` on all subsequent requests. Uses an Agent for state.
  defp build_sequential_plug(first_body, second_body) do
    {:ok, agent} = Agent.start_link(fn -> {:first, first_body, second_body} end)

    fn conn ->
      body = Agent.get_and_update(agent, &sequential_next/1)

      served =
        case body do
          :rest_body -> second_body
          other -> other
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, served)
    end
  end

  # Returns a Plug that records every request and responds with 200 + body.
  # Each request is sent to `test_pid` as `{:request, conn}`.
  defp capture_request_plug(test_pid, response_body) do
    fn conn ->
      send(test_pid, {:request, conn})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, response_body)
    end
  end

  # Agent state transition used by capture_sequential_plug/3.
  # Returns {{body, label}, next_state}.
  defp capture_sequential_next({:first, first_body, second_body}),
    do: {{first_body, :first}, {:second, second_body}}

  defp capture_sequential_next({:second, second_body}),
    do: {{second_body, :second}, {:second, second_body}}

  # Returns a sequential capturing Plug: records each request and serves
  # `first_body` on request 1 and `second_body` on request 2+.
  defp capture_sequential_plug(test_pid, first_body, second_body) do
    {:ok, agent} = Agent.start_link(fn -> {:first, first_body, second_body} end)

    fn conn ->
      {body, label} = Agent.get_and_update(agent, &capture_sequential_next/1)

      send(test_pid, {:request, label, conn})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end
  end

  # ---------------------------------------------------------------------------
  # Private test helper
  # ---------------------------------------------------------------------------

  defp get_req_header(%Plug.Conn{} = conn, header_name) do
    Enum.flat_map(conn.req_headers, fn {name, value} ->
      if String.downcase(name) == header_name, do: [value], else: []
    end)
  end

  # ---------------------------------------------------------------------------
  # fetch_metrics/2
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2" do
    test "returns ok tuple with list of metrics for valid integration and options" do
      plug =
        build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      assert is_list(metrics)
      assert metrics != []
    end

    test "extracts access_token from integration struct" do
      test_pid = self()
      plug = capture_request_plug(test_pid, profit_and_loss_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert ["Bearer qb_valid_access_token"] = get_req_header(conn, "authorization")
    end

    test "includes OAuth token in Authorization header with Bearer prefix" do
      test_pid = self()
      plug = capture_request_plug(test_pid, profit_and_loss_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      [auth_header] = get_req_header(conn, "authorization")
      assert String.starts_with?(auth_header, "Bearer ")
      assert String.contains?(auth_header, "qb_valid_access_token")
    end

    test "builds correct QuickBooks API URL with realm_id for ProfitAndLoss report" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.request_path, "1234567890")
      assert String.contains?(conn.request_path, "ProfitAndLoss")
    end

    test "builds correct QuickBooks API URL with realm_id for BalanceSheet report" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, :second, conn}
      assert String.contains?(conn.request_path, "1234567890")
      assert String.contains?(conn.request_path, "BalanceSheet")
    end

    test "sets realm_id from options when provided" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      integration_without_metadata =
        struct!(Integration,
          id: 10,
          provider: :quickbooks,
          access_token: "qb_token",
          expires_at: future_expires_at(),
          granted_scopes: ["com.intuit.quickbooks.accounting"],
          provider_metadata: %{},
          user_id: 1
        )

      capture_log(fn ->
        QuickBooks.fetch_metrics(integration_without_metadata,
          realm_id: "realm_from_opts",
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.request_path, "realm_from_opts")
    end

    test "sets realm_id from provider_metadata when not in options" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.request_path, "1234567890")
    end

    test "sets start_date and end_date query parameters from date_range option" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          date_range: {~D[2026-01-01], ~D[2026-01-31]},
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.query_string, "start_date=2026-01-01")
      assert String.contains?(conn.query_string, "end_date=2026-01-31")
    end

    test "defaults to last 30 days when date_range not provided" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())
      today = Date.utc_today()
      expected_start = Date.add(today, -30)

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.query_string, "end_date=#{Date.to_iso8601(today)}")
      assert String.contains?(conn.query_string, "start_date=#{Date.to_iso8601(expected_start)}")
    end

    test "formats dates as YYYY-MM-DD in query parameters" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          date_range: {~D[2026-01-01], ~D[2026-01-31]},
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert Regex.match?(~r/start_date=\d{4}-\d{2}-\d{2}/, conn.query_string)
      assert Regex.match?(~r/end_date=\d{4}-\d{2}-\d{2}/, conn.query_string)
    end

    test "includes accounting_method query parameter with default Accrual" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.query_string, "accounting_method=Accrual")
    end

    test "allows accounting_method to be overridden in options" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          accounting_method: "Cash",
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, conn}
      assert String.contains?(conn.query_string, "accounting_method=Cash")
    end

    test "includes Accept header with application/json" do
      test_pid = self()
      plug = capture_request_plug(test_pid, profit_and_loss_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert ["application/json"] = get_req_header(conn, "accept")
    end

    test "fetches both ProfitAndLoss and BalanceSheet reports" do
      test_pid = self()
      plug = capture_sequential_plug(test_pid, profit_and_loss_response(), balance_sheet_response())

      capture_log(fn ->
        QuickBooks.fetch_metrics(valid_integration(),
          realm_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, :first, pl_conn}
      assert_receive {:request, :second, bs_conn}
      assert String.contains?(pl_conn.request_path, "ProfitAndLoss")
      assert String.contains?(bs_conn.request_path, "BalanceSheet")
    end

    test "transforms QuickBooks report response to unified metric format" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      assert Enum.all?(metrics, &is_map/1)

      for metric <- metrics do
        assert Map.has_key?(metric, :metric_type)
        assert Map.has_key?(metric, :metric_name)
        assert Map.has_key?(metric, :value)
        assert Map.has_key?(metric, :recorded_at)
        assert Map.has_key?(metric, :metadata)
        assert Map.has_key?(metric, :provider)
      end
    end

    test "sets provider to :quickbooks for all metrics" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      for metric <- metrics do
        assert metric.provider == :quickbooks
      end
    end

    test "sets recorded_at to end date from date_range" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 date_range: {~D[2026-01-01], ~D[2026-01-31]},
                 http_plug: plug
               )

      for metric <- metrics do
        assert %DateTime{} = metric.recorded_at
        assert metric.recorded_at.year == 2026
        assert metric.recorded_at.month == 1
        assert metric.recorded_at.day == 31
      end
    end

    test "navigates Rows hierarchy to extract revenue from Income section" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      revenue_metric = Enum.find(metrics, fn m -> m.metric_name == "revenue" end)
      assert revenue_metric != nil
      assert revenue_metric.value == 80_000.0
    end

    test "navigates Rows hierarchy to extract expenses from Expenses section" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      expenses_metric = Enum.find(metrics, fn m -> m.metric_name == "expenses" end)
      assert expenses_metric != nil
      assert expenses_metric.value == 30_000.0
    end

    test "extracts net_income from Net Income row" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      net_income_metric = Enum.find(metrics, fn m -> m.metric_name == "net_income" end)
      assert net_income_metric != nil
      assert net_income_metric.value == 30_000.0
    end

    test "calculates gross_profit from revenue and cost_of_goods_sold" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      gross_profit_metric = Enum.find(metrics, fn m -> m.metric_name == "gross_profit" end)
      assert gross_profit_metric != nil
      # revenue 80_000 - cogs 20_000 = 60_000
      assert gross_profit_metric.value == 60_000.0
    end

    test "extracts accounts_receivable from Assets section" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      ar_metric = Enum.find(metrics, fn m -> m.metric_name == "accounts_receivable" end)
      assert ar_metric != nil
      assert ar_metric.value == 12_000.0
    end

    test "extracts accounts_payable from Liabilities section" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      ap_metric = Enum.find(metrics, fn m -> m.metric_name == "accounts_payable" end)
      assert ap_metric != nil
      assert ap_metric.value == 8_000.0
    end

    test "extracts cash_on_hand from Cash or Bank accounts" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      cash_metric = Enum.find(metrics, fn m -> m.metric_name == "cash_on_hand" end)
      assert cash_metric != nil
      assert cash_metric.value == 15_000.0
    end

    test "handles nested account hierarchy in Rows structure" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      # AR and Bank accounts are nested inside CurrentAssets inside Assets;
      # assert both are present and non-zero to confirm hierarchy traversal works.
      ar_metric = Enum.find(metrics, fn m -> m.metric_name == "accounts_receivable" end)
      cash_metric = Enum.find(metrics, fn m -> m.metric_name == "cash_on_hand" end)
      assert ar_metric.value > 0
      assert cash_metric.value > 0
    end

    test "sums multiple account values within Income section for total revenue" do
      # The P&L fixture has two income rows: 50_000 + 30_000 = 80_000.
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      revenue_metric = Enum.find(metrics, fn m -> m.metric_name == "revenue" end)
      assert revenue_metric.value == 80_000.0
    end

    test "sums multiple account values within Expenses section for total expenses" do
      # Rent 5_000 + Salaries 25_000 = 30_000.
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      expenses_metric = Enum.find(metrics, fn m -> m.metric_name == "expenses" end)
      assert expenses_metric.value == 30_000.0
    end

    test "converts metric values to float for currency amounts" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      for metric <- metrics do
        assert is_float(metric.value)
      end
    end

    test "includes realm_id in metadata" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      for metric <- metrics do
        assert metric.metadata.realm_id == "1234567890"
      end
    end

    test "includes accounting_method in metadata" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      for metric <- metrics do
        assert Map.has_key?(metric.metadata, :accounting_method)
      end
    end

    test "includes report_type in metadata (profit_and_loss or balance_sheet)" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      report_types = Enum.map(metrics, fn m -> m.metadata.report_type end)
      assert Enum.any?(report_types, fn t -> t == :profit_and_loss end)
      assert Enum.any?(report_types, fn t -> t == :balance_sheet end)
    end

    test "returns error :missing_realm_id when realm_id not in options or metadata" do
      assert {:error, :missing_realm_id} =
               QuickBooks.fetch_metrics(integration_without_realm_id(), [])
    end

    test "returns error :unauthorized when token is invalid or expired" do
      assert {:error, :unauthorized} =
               QuickBooks.fetch_metrics(expired_integration(), realm_id: "1234567890")
    end

    test "returns error :insufficient_permissions when token lacks accounting scope" do
      plug = build_stub_plug(403, Jason.encode!(%{"fault" => %{"error" => [%{"code" => "3200"}]}}))

      assert {:error, :insufficient_permissions} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )
    end

    test "returns error :company_not_found when realm_id doesn't exist or user lacks access" do
      plug = build_stub_plug(404, Jason.encode!(%{"fault" => %{"error" => [%{"code" => "610"}]}}))

      assert {:error, :company_not_found} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "nonexistent_realm",
                 http_plug: plug
               )
    end

    test "returns error with QuickBooks API details when request is invalid" do
      error_body =
        Jason.encode!(%{
          "fault" => %{
            "error" => [
              %{"code" => "4000", "detail" => "Invalid date format", "message" => "Bad request"}
            ]
          }
        })

      plug = build_stub_plug(400, error_body)

      assert {:error, _details} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )
    end

    test "handles network errors gracefully with error tuple" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      assert {:error, {:network_error, _reason}} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: error_plug
               )
    end

    test "handles malformed JSON response with error tuple" do
      malformed_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:error, :malformed_response} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: malformed_plug
               )
    end

    test "handles empty Rows array with zero values for metrics" do
      plug = build_sequential_plug(empty_profit_and_loss_response(), empty_balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      for metric <- metrics do
        assert metric.value == 0.0
      end
    end

    test "handles missing Income section by setting revenue to zero" do
      plug =
        build_sequential_plug(
          profit_and_loss_no_income_response(),
          balance_sheet_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      revenue_metric = Enum.find(metrics, fn m -> m.metric_name == "revenue" end)
      assert revenue_metric != nil
      assert revenue_metric.value == 0.0
    end

    test "handles missing Expenses section by setting expenses to zero" do
      plug =
        build_sequential_plug(
          profit_and_loss_no_expenses_response(),
          balance_sheet_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      expenses_metric = Enum.find(metrics, fn m -> m.metric_name == "expenses" end)
      assert expenses_metric != nil
      assert expenses_metric.value == 0.0
    end

    test "handles missing Net Income row by calculating from revenue minus expenses" do
      # The no-income response has only Expenses and no NetIncome Summary row.
      plug =
        build_sequential_plug(
          profit_and_loss_no_income_response(),
          balance_sheet_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      net_income_metric = Enum.find(metrics, fn m -> m.metric_name == "net_income" end)
      assert net_income_metric != nil
      assert is_float(net_income_metric.value)
    end

    test "handles missing accounts_receivable by setting to zero" do
      plug =
        build_sequential_plug(
          profit_and_loss_response(),
          balance_sheet_no_ar_ap_cash_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      ar_metric = Enum.find(metrics, fn m -> m.metric_name == "accounts_receivable" end)
      assert ar_metric != nil
      assert ar_metric.value == 0.0
    end

    test "handles missing accounts_payable by setting to zero" do
      plug =
        build_sequential_plug(
          profit_and_loss_response(),
          balance_sheet_no_ar_ap_cash_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      ap_metric = Enum.find(metrics, fn m -> m.metric_name == "accounts_payable" end)
      assert ap_metric != nil
      assert ap_metric.value == 0.0
    end

    test "handles missing cash accounts by setting cash_on_hand to zero" do
      plug =
        build_sequential_plug(
          profit_and_loss_response(),
          balance_sheet_no_ar_ap_cash_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      cash_metric = Enum.find(metrics, fn m -> m.metric_name == "cash_on_hand" end)
      assert cash_metric != nil
      assert cash_metric.value == 0.0
    end

    test "handles reports with no data for date range with empty or zero values" do
      plug =
        build_sequential_plug(
          empty_profit_and_loss_response(),
          empty_balance_sheet_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 date_range: {~D[2020-01-01], ~D[2020-01-31]},
                 http_plug: plug
               )

      assert is_list(metrics)

      for metric <- metrics do
        assert metric.value == 0.0
      end
    end

    test "parses ColData array within Rows to extract numeric values" do
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      revenue_metric = Enum.find(metrics, fn m -> m.metric_name == "revenue" end)
      assert revenue_metric.value == 80_000.0
    end

    test "handles Summary rows correctly without duplication" do
      # Revenue should equal the Summary total (80_000), not double-counted
      # from individual rows (50_000 + 30_000) plus the Summary row.
      plug = build_sequential_plug(profit_and_loss_response(), balance_sheet_response())

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      revenue_metric = Enum.find(metrics, fn m -> m.metric_name == "revenue" end)
      assert revenue_metric.value == 80_000.0
    end

    test "handles multi-currency scenarios using HomeCurrencyAmount when present" do
      plug =
        build_sequential_plug(
          profit_and_loss_response(),
          balance_sheet_multi_currency_response()
        )

      assert {:ok, metrics} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 http_plug: plug
               )

      cash_metric = Enum.find(metrics, fn m -> m.metric_name == "cash_on_hand" end)
      assert cash_metric != nil
      # When homeCurrencyAmount is present the provider should prefer it.
      assert cash_metric.value == 8_500.0
    end

    test "validates date_range start is before end date" do
      assert {:error, :invalid_date_range} =
               QuickBooks.fetch_metrics(valid_integration(),
                 realm_id: "1234567890",
                 date_range: {~D[2026-01-31], ~D[2026-01-01]}
               )
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :quickbooks atom" do
      assert QuickBooks.provider() == :quickbooks
    end

    test "return value matches Integration.provider enum value" do
      valid_providers = [
        :github,
        :gitlab,
        :bitbucket,
        :google,
        :google_ads,
        :facebook_ads,
        :google_analytics,
        :quickbooks
      ]

      assert QuickBooks.provider() in valid_providers
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list with accounting scope" do
      scopes = QuickBooks.required_scopes()

      assert is_list(scopes)
      assert Enum.any?(scopes, fn s -> String.contains?(s, "accounting") end)
    end

    test "scope string is properly formatted" do
      scopes = QuickBooks.required_scopes()

      assert Enum.all?(scopes, fn scope -> String.match?(scope, ~r/^com\.intuit\./) end)
    end

    test "returned scopes are strings not atoms" do
      scopes = QuickBooks.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list contains exactly one scope" do
      scopes = QuickBooks.required_scopes()

      assert length(scopes) == 1
    end

    test "scope matches QuickBooks Online API requirements" do
      scopes = QuickBooks.required_scopes()

      assert "com.intuit.quickbooks.accounting" in scopes
    end

    test "accounting scope provides read access to financial reports" do
      scopes = QuickBooks.required_scopes()

      assert Enum.any?(scopes, fn s -> String.contains?(s, "quickbooks.accounting") end)
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
