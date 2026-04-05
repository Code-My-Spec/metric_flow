defmodule MetricFlow.Integrations.GoogleAdsAccountsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.GoogleAdsAccounts
  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :google_ads,
      access_token: "ya29.valid_google_ads_token",
      refresh_token: "1//refresh_token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["https://www.googleapis.com/auth/adwords"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  # JSON-encoded listAccessibleCustomers response with two customers.
  defp list_customers_response(resource_names) do
    Jason.encode!(%{"resourceNames" => resource_names})
  end

  # JSON-encoded searchStream response for a single customer with a descriptive name.
  defp search_stream_response(descriptive_name, manager \\ false) do
    Jason.encode!([
      %{
        "results" => [
          %{
            "customer" => %{
              "descriptiveName" => descriptive_name,
              "id" => "1234567890",
              "manager" => manager
            }
          }
        ]
      }
    ])
  end

  # searchStream response with no results (empty results list).
  defp empty_search_stream_response do
    Jason.encode!([%{"results" => []}])
  end

  # searchStream response where descriptive name is blank.
  defp blank_name_search_stream_response do
    Jason.encode!([
      %{
        "results" => [
          %{
            "customer" => %{
              "descriptiveName" => "",
              "id" => "111222333",
              "manager" => false
            }
          }
        ]
      }
    ])
  end

  # Map-style (single object) searchStream body — when Req auto-decodes a single-element array.
  defp map_style_search_stream_response(descriptive_name) do
    Jason.encode!(%{
      "results" => [
        %{
          "customer" => %{
            "descriptiveName" => descriptive_name,
            "id" => "9876543210",
            "manager" => false
          }
        }
      ]
    })
  end

  # Builds a simple stub plug that responds with a fixed status and body.
  defp build_stub_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  # Builds a plug that responds differently depending on whether the request
  # URL contains the listAccessibleCustomers path or a searchStream path.
  defp build_two_phase_plug(list_status, list_body, search_status, search_body) do
    fn conn ->
      if String.contains?(conn.request_path, "listAccessibleCustomers") do
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(list_status, list_body)
      else
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(search_status, search_body)
      end
    end
  end

  # Plug that captures request headers and forwards them to the test process.
  defp capture_headers_plug(test_pid, list_body, search_body) do
    fn conn ->
      send(test_pid, {:request, conn})

      response_body =
        if String.contains?(conn.request_path, "listAccessibleCustomers"),
          do: list_body,
          else: search_body

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, response_body)
    end
  end

  defp get_req_header(%Plug.Conn{} = conn, header_name) do
    Enum.flat_map(conn.req_headers, fn {name, value} ->
      if String.downcase(name) == header_name, do: [value], else: []
    end)
  end

  # ---------------------------------------------------------------------------
  # list_customers/2
  # ---------------------------------------------------------------------------

  describe "list_customers/2" do
    test "returns ok tuple with list of customer maps on a successful API response" do
      resource_names = ["customers/111", "customers/222"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          search_stream_response("Test Account")
        )

      assert {:ok, customers} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert is_list(customers)
    end

    test "each returned customer map has :id, :name, and :account keys" do
      resource_names = ["customers/111222333"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          search_stream_response("My Business")
        )

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert Map.has_key?(customer, :id)
      assert Map.has_key?(customer, :name)
      assert Map.has_key?(customer, :account)
    end

    test "sets :account to \"Google Ads\" for every customer" do
      resource_names = ["customers/111", "customers/222"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          search_stream_response("Account Name")
        )

      assert {:ok, customers} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      for customer <- customers do
        assert customer.account == "Google Ads"
      end
    end

    test "extracts :id from the \"resourceNames\" list by stripping the \"customers/\" prefix" do
      resource_names = ["customers/1234567890"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          search_stream_response("Test Business")
        )

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert customer.id == "1234567890"
    end

    test "resolves :name by querying each customer's googleAds:searchStream endpoint" do
      resource_names = ["customers/999888777"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          search_stream_response("Resolved Name From API")
        )

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert customer.name == "Resolved Name From API"
    end

    test "defaults :name to \"Account <id>\" when the searchStream request fails or returns no name" do
      resource_names = ["customers/555444333"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          500,
          Jason.encode!(%{"error" => "internal server error"})
        )

      capture_log(fn ->
        assert {:ok, [customer]} =
                 GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

        assert customer.name == "Account 555444333"
      end)
    end

    test "defaults :name to \"Account <id>\" when the searchStream returns no results" do
      resource_names = ["customers/777666555"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          empty_search_stream_response()
        )

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert customer.name == "Account 777666555"
    end

    test "defaults :name to \"Account <id>\" when the descriptive name in the response is blank" do
      resource_names = ["customers/111222333"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          blank_name_search_stream_response()
        )

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert customer.name == "Account 111222333"
    end

    test "returns {:error, :unauthorized} on a 401 response from listAccessibleCustomers" do
      plug = build_stub_plug(401, Jason.encode!(%{"error" => "unauthorized"}))

      capture_log(fn ->
        assert {:error, :unauthorized} =
                 GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :api_disabled} on a 403 response from listAccessibleCustomers" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "forbidden"}))

      capture_log(fn ->
        assert {:error, :api_disabled} =
                 GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :bad_request} on an unexpected HTTP status from listAccessibleCustomers" do
      plug = build_stub_plug(400, Jason.encode!(%{"error" => "bad request"}))

      capture_log(fn ->
        assert {:error, :bad_request} =
                 GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, {:network_error, message}} when the listAccessibleCustomers request raises an exception" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      capture_log(fn ->
        assert {:error, {:network_error, message}} =
                 GoogleAdsAccounts.list_customers(valid_integration(), http_plug: error_plug)

        assert is_binary(message)
      end)
    end

    test "returns {:ok, []} when \"resourceNames\" is present but empty" do
      plug = build_stub_plug(200, list_customers_response([]))

      assert {:ok, []} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
    end

    test "handles a 200 response with a binary JSON body by decoding before extracting customer IDs" do
      # Simulate Req returning raw binary instead of a decoded map by manually
      # building a binary-body plug using a raw Plug.Conn send.
      binary_body = ~s({"resourceNames":["customers/123456789"]})

      binary_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, binary_body)
      end

      search_plug = fn conn ->
        if String.contains?(conn.request_path, "listAccessibleCustomers") do
          binary_plug.(conn)
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, search_stream_response("Binary Body Account"))
        end
      end

      assert {:ok, customers} =
               GoogleAdsAccounts.list_customers(valid_integration(), http_plug: search_plug)

      assert is_list(customers)
    end

    test "returns {:ok, []} when the binary body cannot be decoded" do
      invalid_json_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:ok, []} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: invalid_json_plug)
    end

    test "accepts an :http_plug option for test injection without making real HTTP calls" do
      # The plug records whether it was called — if not called, no real HTTP is made.
      test_pid = self()

      plug = fn conn ->
        send(test_pid, :plug_called)
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, list_customers_response([]))
      end

      capture_log(fn ->
        GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)

      assert_receive :plug_called
    end

    test "injects the :http_plug plug for both the listAccessibleCustomers request and each searchStream request" do
      resource_names = ["customers/111", "customers/222"]
      test_pid = self()
      request_count = :counters.new(1, [:atomics])

      counting_plug = fn conn ->
        count = :counters.get(request_count, 1) + 1
        :counters.put(request_count, 1, count)
        send(test_pid, {:request_path, conn.request_path})

        response_body =
          if String.contains?(conn.request_path, "listAccessibleCustomers"),
            do: list_customers_response(resource_names),
            else: search_stream_response("Test")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, response_body)
      end

      assert {:ok, _customers} =
               GoogleAdsAccounts.list_customers(valid_integration(), http_plug: counting_plug)

      # Should receive 1 list call + 2 searchStream calls = 3 total
      assert_receive {:request_path, path_1}
      assert_receive {:request_path, path_2}
      assert_receive {:request_path, path_3}

      paths = [path_1, path_2, path_3]
      assert Enum.any?(paths, &String.contains?(&1, "listAccessibleCustomers"))
      assert Enum.any?(paths, &String.contains?(&1, "googleAds:searchStream"))
    end

    test "includes the developer-token header in all requests" do
      resource_names = ["customers/111222333"]
      test_pid = self()

      plug =
        capture_headers_plug(
          test_pid,
          list_customers_response(resource_names),
          search_stream_response("Dev Token Account")
        )

      capture_log(fn ->
        GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)

      # Collect all requests (list call + searchStream call)
      assert_receive {:request, conn1}
      assert_receive {:request, conn2}

      for conn <- [conn1, conn2] do
        assert get_req_header(conn, "developer-token") != []
      end
    end

    test "includes the login-customer-id header when the config value is non-nil and non-empty" do
      original = Application.get_env(:metric_flow, :google_ads_login_customer_id)
      Application.put_env(:metric_flow, :google_ads_login_customer_id, "9876543210")

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :google_ads_login_customer_id, original),
          else: Application.delete_env(:metric_flow, :google_ads_login_customer_id)
      end)

      test_pid = self()

      plug =
        capture_headers_plug(
          test_pid,
          list_customers_response([]),
          ""
        )

      capture_log(fn ->
        GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert get_req_header(conn, "login-customer-id") == ["9876543210"]
    end

    test "omits the login-customer-id header when the config value is nil" do
      original = Application.get_env(:metric_flow, :google_ads_login_customer_id)
      Application.put_env(:metric_flow, :google_ads_login_customer_id, nil)

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :google_ads_login_customer_id, original),
          else: Application.delete_env(:metric_flow, :google_ads_login_customer_id)
      end)

      test_pid = self()

      plug =
        capture_headers_plug(
          test_pid,
          list_customers_response([]),
          ""
        )

      capture_log(fn ->
        GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert get_req_header(conn, "login-customer-id") == []
    end

    test "omits the login-customer-id header when the config value is an empty string" do
      original = Application.get_env(:metric_flow, :google_ads_login_customer_id)
      Application.put_env(:metric_flow, :google_ads_login_customer_id, "")

      on_exit(fn ->
        if original,
          do: Application.put_env(:metric_flow, :google_ads_login_customer_id, original),
          else: Application.delete_env(:metric_flow, :google_ads_login_customer_id)
      end)

      test_pid = self()

      plug =
        capture_headers_plug(
          test_pid,
          list_customers_response([]),
          ""
        )

      capture_log(fn ->
        GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert get_req_header(conn, "login-customer-id") == []
    end

    test "extracts :name from a list-style searchStream body via batch results" do
      resource_names = ["customers/333444555"]

      plug =
        build_two_phase_plug(
          200,
          list_customers_response(resource_names),
          200,
          search_stream_response("List Style Name")
        )

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert customer.name == "List Style Name"
    end

    test "extracts :name from a map-style searchStream body when Req auto-decodes a single object" do
      resource_names = ["customers/9876543210"]

      plug = fn conn ->
        if String.contains?(conn.request_path, "listAccessibleCustomers") do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, list_customers_response(resource_names))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, map_style_search_stream_response("Map Style Name"))
        end
      end

      assert {:ok, [customer]} = GoogleAdsAccounts.list_customers(valid_integration(), http_plug: plug)

      assert customer.name == "Map Style Name"
    end
  end
end
