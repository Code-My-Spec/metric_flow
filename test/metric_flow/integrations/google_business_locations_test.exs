defmodule MetricFlow.Integrations.GoogleBusinessLocationsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.GoogleBusinessLocations
  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  defp integration_with_account_ids do
    struct!(Integration,
      id: 1,
      provider: :google_business,
      access_token: "ya29.valid_access_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{"google_business_account_ids" => ["accounts/123456789"]},
      user_id: 1
    )
  end

  defp integration_without_account_ids do
    struct!(Integration,
      id: 2,
      provider: :google_business,
      access_token: "ya29.valid_access_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  defp integration_with_multiple_account_ids do
    struct!(Integration,
      id: 3,
      provider: :google_business,
      access_token: "ya29.valid_access_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{
        "google_business_account_ids" => ["accounts/111111111", "accounts/222222222"]
      },
      user_id: 1
    )
  end

  defp location_api_response(account_id, page_token \\ nil) do
    body = %{
      "locations" => [
        %{
          "name" => "locations/abc123",
          "title" => "My Coffee Shop",
          "storeCode" => "SHOP-001",
          "storefrontAddress" => %{
            "addressLines" => ["123 Main St"],
            "locality" => "Springfield",
            "administrativeArea" => "IL",
            "postalCode" => "62701"
          },
          "websiteUri" => "https://mycoffeeshop.example.com",
          "primaryCategory" => %{"displayName" => "Coffee Shop"}
        }
      ]
    }

    body =
      if page_token do
        Map.put(body, "nextPageToken", page_token)
      else
        body
      end

    _ = account_id
    Jason.encode!(body)
  end

  defp paginated_first_page_response do
    Jason.encode!(%{
      "locations" => [
        %{
          "name" => "locations/page1loc",
          "title" => "Location Page 1",
          "storeCode" => "P1-001",
          "storefrontAddress" => nil,
          "websiteUri" => nil,
          "primaryCategory" => nil
        }
      ],
      "nextPageToken" => "next_page_token_abc"
    })
  end

  defp paginated_second_page_response do
    Jason.encode!(%{
      "locations" => [
        %{
          "name" => "locations/page2loc",
          "title" => "Location Page 2",
          "storeCode" => "P2-001",
          "storefrontAddress" => nil,
          "websiteUri" => nil,
          "primaryCategory" => nil
        }
      ]
    })
  end

  defp accounts_api_response do
    Jason.encode!(%{
      "accounts" => [
        %{"name" => "accounts/987654321"},
        %{"name" => "accounts/123456789"}
      ]
    })
  end

  defp empty_accounts_api_response do
    Jason.encode!(%{})
  end

  defp empty_locations_api_response do
    Jason.encode!(%{})
  end

  defp build_stub_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  defp build_multi_response_plug(responses) do
    # Serves responses in order, cycling on index by request count
    counter = :counters.new(1, [:atomics])

    fn conn ->
      index = :counters.get(counter, 1)
      :counters.add(counter, 1, 1)
      {status, body} = Enum.at(responses, index, List.last(responses))

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  # ---------------------------------------------------------------------------
  # list_locations/2
  # ---------------------------------------------------------------------------

  describe "list_locations/2" do
    test "returns {:ok, locations} with a list of location maps on successful API response" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, locations} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert is_list(locations)
      assert length(locations) == 1
    end

    test "each returned location map has :id, :name, :account, :store_code, :address, :website, and :category keys" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert Map.has_key?(location, :id)
      assert Map.has_key?(location, :name)
      assert Map.has_key?(location, :account)
      assert Map.has_key?(location, :store_code)
      assert Map.has_key?(location, :address)
      assert Map.has_key?(location, :website)
      assert Map.has_key?(location, :category)
    end

    test "location :id is a fully qualified account/location path" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert location.id == "accounts/123456789/locations/abc123"
    end

    test "location :name contains the business title from the API response" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert location.name == "My Coffee Shop"
    end

    test "location :account reflects a human-readable account label" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert location.account == "Account 123456789"
    end

    test "location :store_code matches storeCode from the API response" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert location.store_code == "SHOP-001"
    end

    test "location :website matches websiteUri from the API response" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert location.website == "https://mycoffeeshop.example.com"
    end

    test "location :category matches primaryCategory displayName from the API response" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert location.category == "Coffee Shop"
    end

    test "location :address formats the storefrontAddress into a single string" do
      plug = build_stub_plug(200, location_api_response("accounts/123456789"))

      assert {:ok, [location | _]} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert is_binary(location.address)
      assert String.contains?(location.address, "123 Main St")
      assert String.contains?(location.address, "Springfield")
    end

    test "handles pagination via nextPageToken" do
      plug =
        build_multi_response_plug([
          {200, paginated_first_page_response()},
          {200, paginated_second_page_response()}
        ])

      assert {:ok, locations} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )

      assert length(locations) == 2
    end

    test "merges locations across multiple accounts into a flat list" do
      plug = build_stub_plug(200, location_api_response("accounts/111111111"))

      assert {:ok, locations} =
               GoogleBusinessLocations.list_locations(integration_with_multiple_account_ids(),
                 http_plug: plug
               )

      assert is_list(locations)
      assert length(locations) == 2
    end

    test "falls back to fetching accounts when provider_metadata has no account IDs" do
      plug =
        build_multi_response_plug([
          {200, accounts_api_response()},
          {200, location_api_response("accounts/987654321")},
          {200, location_api_response("accounts/123456789")}
        ])

      assert {:ok, locations} =
               GoogleBusinessLocations.list_locations(integration_without_account_ids(),
                 http_plug: plug
               )

      assert is_list(locations)
      assert length(locations) > 0
    end

    test "returns {:error, :no_accounts_configured} when no account IDs found" do
      plug =
        build_multi_response_plug([
          {200, empty_accounts_api_response()}
        ])

      capture_log(fn ->
        assert {:error, :no_accounts_configured} =
                 GoogleBusinessLocations.list_locations(integration_without_account_ids(),
                   http_plug: plug
                 )
      end)
    end

    test "returns {:error, :unauthorized} on 401 response" do
      plug = build_stub_plug(401, Jason.encode!(%{"error" => "unauthorized"}))

      capture_log(fn ->
        assert {:error, :unauthorized} =
                 GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                   http_plug: plug
                 )
      end)
    end

    test "returns {:error, :api_disabled} on 403 response" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "forbidden"}))

      capture_log(fn ->
        assert {:error, :api_disabled} =
                 GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                   http_plug: plug
                 )
      end)
    end

    test "accepts :http_plug option for test injection" do
      plug = build_stub_plug(200, empty_locations_api_response())

      assert {:ok, _locations} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )
    end

    test "returns {:ok, []} when account locations response has no locations key" do
      plug = build_stub_plug(200, empty_locations_api_response())

      assert {:ok, []} =
               GoogleBusinessLocations.list_locations(integration_with_account_ids(),
                 http_plug: plug
               )
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_accounts/2
  # ---------------------------------------------------------------------------

  describe "fetch_accounts/2" do
    test "returns {:ok, account_ids} with list of account name strings on success" do
      plug = build_stub_plug(200, accounts_api_response())

      assert {:ok, account_ids} =
               GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                 http_plug: plug
               )

      assert is_list(account_ids)
      assert "accounts/987654321" in account_ids
      assert "accounts/123456789" in account_ids
    end

    test "account_ids are strings" do
      plug = build_stub_plug(200, accounts_api_response())

      assert {:ok, account_ids} =
               GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                 http_plug: plug
               )

      assert Enum.all?(account_ids, &is_binary/1)
    end

    test "returns {:ok, []} when response has no accounts" do
      plug = build_stub_plug(200, empty_accounts_api_response())

      assert {:ok, []} =
               GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                 http_plug: plug
               )
    end

    test "returns {:ok, []} when response has accounts key with empty list" do
      plug = build_stub_plug(200, Jason.encode!(%{"accounts" => []}))

      assert {:ok, []} =
               GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                 http_plug: plug
               )
    end

    test "returns {:error, :unauthorized} on 401 response" do
      plug = build_stub_plug(401, Jason.encode!(%{"error" => "unauthorized"}))

      capture_log(fn ->
        assert {:error, :unauthorized} =
                 GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                   http_plug: plug
                 )
      end)
    end

    test "returns {:error, :api_disabled} on 403 response" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "forbidden"}))

      capture_log(fn ->
        assert {:error, :api_disabled} =
                 GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                   http_plug: plug
                 )
      end)
    end

    test "returns {:error, :bad_request} on unexpected status" do
      plug = build_stub_plug(500, Jason.encode!(%{"error" => "internal server error"}))

      capture_log(fn ->
        assert {:error, :bad_request} =
                 GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                   http_plug: plug
                 )
      end)
    end

    test "returns {:error, {:network_error, message}} on exception" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      capture_log(fn ->
        assert {:error, {:network_error, message}} =
                 GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                   http_plug: error_plug
                 )

        assert is_binary(message)
      end)
    end

    test "accepts :http_plug option for test injection" do
      plug = build_stub_plug(200, accounts_api_response())

      assert {:ok, _account_ids} =
               GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
                 http_plug: plug
               )
    end

    test "uses Bearer token from integration access_token in Authorization header" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:request_headers, conn.req_headers})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, accounts_api_response())
      end

      capture_log(fn ->
        GoogleBusinessLocations.fetch_accounts(integration_without_account_ids(),
          http_plug: plug
        )
      end)

      assert_receive {:request_headers, headers}

      auth_value =
        Enum.find_value(headers, fn {name, value} ->
          if String.downcase(name) == "authorization", do: value
        end)

      assert auth_value == "Bearer ya29.valid_access_token"
    end
  end
end
