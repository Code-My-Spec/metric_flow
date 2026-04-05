defmodule MetricFlow.Integrations.GoogleAccountsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.GoogleAccounts
  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :google_analytics,
      access_token: "ya29.valid_access_token",
      refresh_token: "1//refresh_token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  defp account_summaries_response do
    Jason.encode!(%{
      "accountSummaries" => [
        %{
          "account" => "accounts/123",
          "displayName" => "Acme Corp",
          "propertySummaries" => [
            %{
              "property" => "properties/111",
              "displayName" => "Main Website"
            },
            %{
              "property" => "properties/222",
              "displayName" => "Mobile App"
            }
          ]
        },
        %{
          "account" => "accounts/456",
          "displayName" => "Beta Inc",
          "propertySummaries" => [
            %{
              "property" => "properties/333",
              "displayName" => "Beta Site"
            }
          ]
        }
      ]
    })
  end

  defp single_account_response do
    Jason.encode!(%{
      "accountSummaries" => [
        %{
          "account" => "accounts/100",
          "displayName" => "Single Account",
          "propertySummaries" => [
            %{
              "property" => "properties/999",
              "displayName" => "Only Property"
            }
          ]
        }
      ]
    })
  end

  defp empty_summaries_response do
    Jason.encode!(%{"accountSummaries" => []})
  end

  defp summary_without_properties_response do
    Jason.encode!(%{
      "accountSummaries" => [
        %{
          "account" => "accounts/789",
          "displayName" => "Account Without Properties"
        }
      ]
    })
  end

  defp missing_account_summaries_response do
    Jason.encode!(%{"kind" => "analyticsadmin#listAccountSummariesResponse"})
  end

  defp missing_display_names_response do
    Jason.encode!(%{
      "accountSummaries" => [
        %{
          "account" => "accounts/100",
          "propertySummaries" => [
            %{
              "property" => "properties/200"
            }
          ]
        }
      ]
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
      send(test_pid, {:request, conn})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, single_account_response())
    end
  end

  defp get_req_header(%Plug.Conn{} = conn, header_name) do
    Enum.flat_map(conn.req_headers, fn {name, value} ->
      if String.downcase(name) == header_name, do: [value], else: []
    end)
  end

  # ---------------------------------------------------------------------------
  # list_ga4_properties/2
  # ---------------------------------------------------------------------------

  describe "list_ga4_properties/2" do
    test "returns {:ok, properties} with a list of property maps on a 200 response with valid JSON body" do
      plug = build_stub_plug(200, account_summaries_response())

      assert {:ok, properties} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert is_list(properties)
      assert length(properties) == 3
    end

    test "each returned property map has :id, :name, and :account keys" do
      plug = build_stub_plug(200, account_summaries_response())

      assert {:ok, [first | _rest]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert Map.has_key?(first, :id)
      assert Map.has_key?(first, :name)
      assert Map.has_key?(first, :account)
    end

    test "extracts :id from the property \"property\" field" do
      plug = build_stub_plug(200, single_account_response())

      assert {:ok, [property]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert property.id == "properties/999"
    end

    test "extracts :name from the property \"displayName\" field" do
      plug = build_stub_plug(200, single_account_response())

      assert {:ok, [property]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert property.name == "Only Property"
    end

    test "extracts :account from the account summary \"displayName\" field" do
      plug = build_stub_plug(200, single_account_response())

      assert {:ok, [property]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert property.account == "Single Account"
    end

    test "flattens properties across multiple account summaries into a single list" do
      plug = build_stub_plug(200, account_summaries_response())

      assert {:ok, properties} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert length(properties) == 3

      accounts = Enum.map(properties, & &1.account) |> Enum.uniq() |> Enum.sort()
      assert accounts == ["Acme Corp", "Beta Inc"]
    end

    test "returns {:ok, []} when \"accountSummaries\" is present but empty" do
      plug = build_stub_plug(200, empty_summaries_response())

      assert {:ok, []} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
    end

    test "returns {:ok, []} when a summary has no \"propertySummaries\" key" do
      plug = build_stub_plug(200, summary_without_properties_response())

      assert {:ok, []} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
    end

    test "defaults :name to \"Unnamed Property\" when property displayName is absent" do
      plug = build_stub_plug(200, missing_display_names_response())

      assert {:ok, [property]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert property.name == "Unnamed Property"
    end

    test "defaults :account to \"Unknown Account\" when account summary displayName is absent" do
      plug = build_stub_plug(200, missing_display_names_response())

      assert {:ok, [property]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert property.account == "Unknown Account"
    end

    test "returns {:error, :api_disabled} on a 403 response" do
      plug = build_stub_plug(403, ~s({"error": {"code": 403, "status": "PERMISSION_DENIED"}}))

      assert capture_log(fn ->
               assert {:error, :api_disabled} =
                        GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
             end) =~ ~r/403/
    end

    test "returns {:error, :unauthorized} on a 401 response" do
      plug = build_stub_plug(401, ~s({"error": {"code": 401, "status": "UNAUTHENTICATED"}}))

      assert {:error, :unauthorized} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
    end

    test "returns {:error, :bad_request} on an unexpected HTTP status code" do
      plug = build_stub_plug(500, ~s({"error": "internal"}))

      assert capture_log(fn ->
               assert {:error, :bad_request} =
                        GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
             end) =~ ~r/500/
    end

    test "returns {:error, :malformed_response} on a 200 response with a non-JSON binary body" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "this is not valid json {{{{")
      end

      assert {:error, :malformed_response} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
    end

    test "returns {:error, {:network_error, message}} when the HTTP request raises an exception" do
      plug = fn _conn ->
        raise RuntimeError, "simulated network failure"
      end

      assert capture_log(fn ->
               assert {:error, {:network_error, message}} =
                        GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

               assert is_binary(message)
               assert String.contains?(message, "simulated network failure")
             end) =~ "simulated network failure"
    end

    test "accepts an :http_plug option for test injection without making real HTTP calls" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert_receive {:request, _conn}
    end

    test "handles 200 response with binary JSON body by decoding before extracting properties" do
      binary_body = single_account_response()

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, binary_body)
      end

      assert {:ok, [property]} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert property.id == "properties/999"
      assert property.name == "Only Property"
      assert property.account == "Single Account"
    end

    test "handles missing \"accountSummaries\" key in response body by returning empty list" do
      plug = build_stub_plug(200, missing_account_summaries_response())

      assert {:ok, []} =
               GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)
    end

    test "includes Bearer token from integration access_token in Authorization header" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      GoogleAccounts.list_ga4_properties(valid_integration(), http_plug: plug)

      assert_receive {:request, conn}
      assert ["Bearer ya29.valid_access_token"] = get_req_header(conn, "authorization")
    end
  end
end
