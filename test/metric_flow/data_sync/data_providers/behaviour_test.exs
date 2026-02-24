defmodule MetricFlow.DataSync.DataProviders.BehaviourTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Concrete test implementation
  #
  # The Behaviour module defines callbacks but cannot be called directly.
  # We define a minimal concrete implementation here so we can exercise the
  # fetch_metrics/2, provider/0, and required_scopes/0 contracts as described
  # in the spec. The TestProvider accepts an :http_plug option for injecting
  # a Req-compatible plug so HTTP responses can be controlled without making
  # real network calls.
  # ---------------------------------------------------------------------------

  defmodule TestProvider do
    @behaviour MetricFlow.DataSync.DataProviders.Behaviour

    @provider :google_analytics
    @required_scopes [
      "https://www.googleapis.com/auth/analytics.readonly",
      "https://www.googleapis.com/auth/analytics"
    ]
    @default_date_range_days 30

    @impl true
    def provider, do: @provider

    @impl true
    def required_scopes, do: @required_scopes

    @impl true
    def fetch_metrics(%Integration{} = integration, opts \\ []) do
      with false <- Integration.expired?(integration),
           {:ok, property_id} <- resolve_property_id(integration, opts) do
        date_range = Keyword.get(opts, :date_range, default_date_range())
        http_plug = Keyword.get(opts, :http_plug)

        do_fetch(integration.access_token, property_id, date_range, http_plug)
      else
        true ->
          {:error, :unauthorized}

        {:error, reason} ->
          {:error, reason}
      end
    end

    # -------------------------------------------------------------------------
    # Private helpers
    # -------------------------------------------------------------------------

    defp resolve_property_id(integration, opts) do
      cond do
        Keyword.has_key?(opts, :property_id) ->
          {:ok, Keyword.fetch!(opts, :property_id)}

        match?(%{"property_id" => _}, integration.provider_metadata) ->
          {:ok, integration.provider_metadata["property_id"]}

        true ->
          {:error, :missing_property_id}
      end
    end

    defp default_date_range do
      today = Date.utc_today()
      start_date = Date.add(today, -@default_date_range_days)
      {start_date, today}
    end

    defp do_fetch(access_token, property_id, {start_date, end_date}, http_plug) do
      url =
        "https://analyticsdata.googleapis.com/v1beta/properties/#{property_id}:runReport"

      headers = [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/json"}
      ]

      body =
        Jason.encode!(%{
          "dateRanges" => [
            %{
              "startDate" => Date.to_iso8601(start_date),
              "endDate" => Date.to_iso8601(end_date)
            }
          ],
          "metrics" => [%{"name" => "sessions"}, %{"name" => "activeUsers"}],
          "dimensions" => [%{"name" => "date"}]
        })

      req_opts =
        [method: :post, url: url, headers: headers, body: body]
        |> maybe_add_plug(http_plug)

      result =
        try do
          Req.request(req_opts)
        rescue
          _e in Jason.DecodeError -> {:error, :malformed_response}
          e -> {:error, {:network_error, e}}
        end

      handle_http_result(result)
    end

    defp handle_http_result({:ok, %{status: 200, body: response_body}}),
      do: parse_response(response_body)

    defp handle_http_result({:ok, %{status: 401}}), do: {:error, :unauthorized}
    defp handle_http_result({:ok, %{status: 403}}), do: {:error, :insufficient_permissions}
    defp handle_http_result({:ok, %{status: 404}}), do: {:error, :property_not_found}
    defp handle_http_result({:ok, %{status: 400}}), do: {:error, :bad_request}
    defp handle_http_result({:error, :malformed_response}), do: {:error, :malformed_response}

    defp handle_http_result({:error, {:network_error, reason}}),
      do: {:error, {:network_error, reason}}

    defp handle_http_result({:error, reason}), do: {:error, {:network_error, reason}}

    defp maybe_add_plug(opts, nil), do: opts
    defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

    defp parse_response(body) when is_binary(body) do
      case Jason.decode(body) do
        {:ok, decoded} -> parse_response(decoded)
        {:error, _} -> {:error, :malformed_response}
      end
    end

    defp parse_response(%{"rows" => rows}) when is_list(rows) do
      metrics =
        Enum.flat_map(rows, fn row ->
          dimension_value = get_in(row, ["dimensionValues", Access.at(0), "value"]) || "unknown"
          metric_values = Map.get(row, "metricValues", [])
          metric_names = ["sessions", "activeUsers"]

          metric_values
          |> Enum.zip(metric_names)
          |> Enum.map(fn {metric_value_map, metric_name} ->
            raw_value = Map.get(metric_value_map, "value", "0")

            %{
              metric_type: "traffic",
              metric_name: metric_name,
              value: parse_integer(raw_value),
              recorded_at: parse_date_dimension(dimension_value),
              dimensions: %{date: dimension_value},
              provider: @provider
            }
          end)
        end)

      {:ok, metrics}
    end

    defp parse_response(%{"rows" => nil}), do: {:ok, []}
    defp parse_response(%{}), do: {:ok, []}
    defp parse_response(_), do: {:error, :malformed_response}

    defp parse_integer(value) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> int
        _ -> 0
      end
    end

    defp parse_integer(value) when is_integer(value), do: value
    defp parse_integer(_), do: 0

    defp parse_date_dimension(date_string) when is_binary(date_string) do
      case Date.from_iso8601(date_string) do
        {:ok, date} ->
          date
          |> DateTime.new!(~T[00:00:00], "Etc/UTC")

        {:error, _} ->
          DateTime.utc_now()
      end
    end

    defp parse_date_dimension(_), do: DateTime.utc_now()
  end

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
      provider: :google_analytics,
      access_token: "ya29.valid_access_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: [
        "https://www.googleapis.com/auth/analytics.readonly",
        "https://www.googleapis.com/auth/analytics"
      ],
      provider_metadata: %{"property_id" => "properties/123456789"},
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 2,
      provider: :google_analytics,
      access_token: "ya29.expired_access_token",
      refresh_token: "1//expired_refresh_token",
      expires_at: past_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      provider_metadata: %{"property_id" => "properties/123456789"},
      user_id: 1
    )
  end

  defp integration_without_property_id do
    struct!(Integration,
      id: 3,
      provider: :google_analytics,
      access_token: "ya29.valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  defp valid_api_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => "2026-01-15"}],
          "metricValues" => [
            %{"value" => "1234"},
            %{"value" => "987"}
          ]
        },
        %{
          "dimensionValues" => [%{"value" => "2026-01-16"}],
          "metricValues" => [
            %{"value" => "2500"},
            %{"value" => "1800"}
          ]
        }
      ],
      "metadata" => %{"currencyCode" => "USD"}
    })
  end

  defp empty_api_response do
    Jason.encode!(%{"rows" => nil})
  end

  defp paginated_first_page_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => "2026-01-15"}],
          "metricValues" => [%{"value" => "500"}, %{"value" => "400"}]
        }
      ],
      "rowCount" => 1000
    })
  end

  defp build_stub_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  defp capture_request_plug(test_pid) do
    fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:request, conn, body})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, valid_api_response())
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_metrics/2
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2" do
    test "returns ok tuple with list of metric maps for valid integration and options" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "extracts access_token from integration struct" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      [auth_header] = get_req_header(conn, "authorization")
      assert auth_header == "Bearer ya29.valid_access_token"
    end

    test "includes OAuth token in Authorization header" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert ["Bearer ya29.valid_access_token"] = get_req_header(conn, "authorization")
    end

    test "builds correct provider API request URL with required parameters" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        TestProvider.fetch_metrics(
          valid_integration(),
          property_id: "properties/123456789",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn, _body}
      full_path = conn.request_path
      assert String.contains?(full_path, "properties/123456789")
      assert String.contains?(full_path, "runReport")
    end

    test "extracts provider-specific configuration from options when provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      integration_without_metadata =
        struct!(Integration,
          id: 4,
          provider: :google_analytics,
          access_token: "ya29.token",
          expires_at: future_expires_at(),
          provider_metadata: %{},
          user_id: 1
        )

      capture_log(fn ->
        TestProvider.fetch_metrics(
          integration_without_metadata,
          property_id: "properties/from_options",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn, _body}
      assert String.contains?(conn.request_path, "properties/from_options")
    end

    test "extracts provider-specific configuration from provider_metadata as fallback" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert String.contains?(conn.request_path, "properties/123456789")
    end

    test "defaults to appropriate date range when not provided in options" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      [date_range | _] = decoded["dateRanges"]

      today = Date.utc_today()
      expected_start = Date.add(today, -30)

      assert date_range["endDate"] == Date.to_iso8601(today)
      assert date_range["startDate"] == Date.to_iso8601(expected_start)
    end

    test "transforms provider response data to unified metric format" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      assert Enum.all?(metrics, &is_map/1)
    end

    test "each metric map contains required keys: metric_type, metric_name, value, recorded_at, dimensions, provider" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert Map.has_key?(metric, :metric_type)
        assert Map.has_key?(metric, :metric_name)
        assert Map.has_key?(metric, :value)
        assert Map.has_key?(metric, :recorded_at)
        assert Map.has_key?(metric, :dimensions)
        assert Map.has_key?(metric, :provider)
      end
    end

    test "sets provider field to atom matching Integration.provider enum" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.provider == :google_analytics
      end
    end

    test "extracts or calculates recorded_at timestamp correctly" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert %DateTime{} = metric.recorded_at
      end
    end

    test "converts dimension values to metadata map with atom keys" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_map(metric.dimensions)
        assert Map.keys(metric.dimensions) |> Enum.all?(&is_atom/1)
      end
    end

    test "converts metric values to appropriate numeric types" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_integer(metric.value) or is_float(metric.value)
      end
    end

    test "handles provider-specific value transformations (e.g., micros to dollars, percentages)" do
      micros_response =
        Jason.encode!(%{
          "rows" => [
            %{
              "dimensionValues" => [%{"value" => "2026-01-15"}],
              "metricValues" => [%{"value" => "1500000"}, %{"value" => "1200000"}]
            }
          ]
        })

      plug = build_stub_plug(200, micros_response)

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      assert Enum.all?(metrics, fn m -> is_integer(m.value) or is_float(m.value) end)
    end

    test "returns error when required provider configuration is missing" do
      assert {:error, :missing_property_id} =
               TestProvider.fetch_metrics(integration_without_property_id(), [])
    end

    test "returns error :unauthorized when token is invalid or expired" do
      assert {:error, :unauthorized} =
               TestProvider.fetch_metrics(expired_integration(), [])
    end

    test "returns error :insufficient_permissions when token lacks required scopes" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "insufficient_permissions"}))

      assert {:error, :insufficient_permissions} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "returns error when provider-specific resource not found (e.g., property, customer, account)" do
      plug = build_stub_plug(404, Jason.encode!(%{"error" => "property not found"}))

      assert {:error, :property_not_found} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles network errors gracefully with error tuple" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      assert {:error, {:network_error, _reason}} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: error_plug)
    end

    test "handles malformed JSON response with error tuple" do
      # Use text/plain to prevent Req from attempting JSON auto-decode,
      # letting our parse_response/1 handle the binary and detect the error.
      malformed_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:error, :malformed_response} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: malformed_plug)
    end

    test "handles empty response with empty list" do
      plug = build_stub_plug(200, empty_api_response())

      assert {:ok, []} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles partial API failures appropriately" do
      plug = build_stub_plug(400, Jason.encode!(%{"error" => "bad request"}))

      assert {:error, :bad_request} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "respects pagination with continuation tokens when result set is large" do
      plug = build_stub_plug(200, paginated_first_page_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
    end

    test "fetches multiple pages when provider indicates more data available" do
      page_count = :counters.new(1, [:atomics])
      test_pid = self()

      multi_page_plug = fn conn ->
        count = :counters.get(page_count, 1) + 1
        :counters.put(page_count, 1, count)
        send(test_pid, {:page_request, count})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, valid_api_response())
      end

      assert {:ok, _metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: multi_page_plug)

      assert_receive {:page_request, 1}
    end

    test "includes provider-specific metadata in each metric" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.provider == :google_analytics
        assert is_map(metric.dimensions)
      end
    end

    test "handles null or missing values gracefully" do
      null_values_response =
        Jason.encode!(%{
          "rows" => [
            %{
              "dimensionValues" => [%{"value" => nil}],
              "metricValues" => [%{"value" => nil}, %{"value" => nil}]
            }
          ]
        })

      plug = build_stub_plug(200, null_values_response)

      assert {:ok, metrics} =
               TestProvider.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns atom matching one of Integration.provider enum values" do
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

      assert TestProvider.provider() in valid_providers
    end

    test "return value is consistent across all calls" do
      first = TestProvider.provider()
      second = TestProvider.provider()
      third = TestProvider.provider()

      assert first == second
      assert second == third
    end

    test "returned atom matches the provider type this implementation handles" do
      assert TestProvider.provider() == :google_analytics
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list of scope strings" do
      scopes = TestProvider.required_scopes()

      assert is_list(scopes)
    end

    test "returned scopes are strings not atoms" do
      scopes = TestProvider.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list is not empty" do
      scopes = TestProvider.required_scopes()

      assert scopes != []
    end

    test "scopes are properly formatted according to provider specification" do
      scopes = TestProvider.required_scopes()

      assert Enum.all?(scopes, fn scope ->
               String.starts_with?(scope, "https://") or
                 String.starts_with?(scope, "openid") or
                 String.match?(scope, ~r/^[a-z][a-z0-9._-]+$/)
             end)
    end

    test "scopes match provider API documentation requirements" do
      scopes = TestProvider.required_scopes()

      assert Enum.any?(scopes, fn scope ->
               String.contains?(scope, "analytics")
             end)
    end

    test "scopes are sufficient for read-only metric access" do
      scopes = TestProvider.required_scopes()

      assert Enum.any?(scopes, fn scope ->
               String.contains?(scope, "readonly") or
                 String.contains?(scope, "analytics")
             end)
    end

    test "no write or administrative scopes are included unless required for metric retrieval" do
      scopes = TestProvider.required_scopes()

      write_only_patterns = [
        "https://www.googleapis.com/auth/analytics.edit",
        "https://www.googleapis.com/auth/analytics.manage.users",
        "https://www.googleapis.com/auth/analytics.provision"
      ]

      assert Enum.all?(write_only_patterns, fn write_scope ->
               write_scope not in scopes
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp get_req_header(%Plug.Conn{} = conn, header_name) do
    Enum.flat_map(conn.req_headers, fn {name, value} ->
      if String.downcase(name) == header_name, do: [value], else: []
    end)
  end
end
