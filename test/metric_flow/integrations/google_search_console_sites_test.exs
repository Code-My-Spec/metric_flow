defmodule MetricFlow.Integrations.GoogleSearchConsoleSitesTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.GoogleSearchConsoleSites

  # ---------------------------------------------------------------------------
  # Fixtures — Integration structs
  # ---------------------------------------------------------------------------

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :google_search_console,
      access_token: "gsc_valid_access_token",
      refresh_token: "gsc_refresh_token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  # ---------------------------------------------------------------------------
  # Fixtures — API response bodies
  # ---------------------------------------------------------------------------

  defp site_list_response do
    Jason.encode!(%{
      "siteEntry" => [
        %{"siteUrl" => "https://example.com/", "permissionLevel" => "siteOwner"},
        %{"siteUrl" => "https://blog.example.org/", "permissionLevel" => "siteOwner"},
        %{"siteUrl" => "sc-domain:mysite.io", "permissionLevel" => "siteFullUser"}
      ]
    })
  end

  defp single_site_response do
    Jason.encode!(%{
      "siteEntry" => [
        %{"siteUrl" => "https://example.com/", "permissionLevel" => "siteOwner"}
      ]
    })
  end

  defp empty_site_entry_response do
    Jason.encode!(%{"siteEntry" => []})
  end

  defp no_site_entry_response do
    Jason.encode!(%{"kind" => "webmasters#sitesListResponse"})
  end

  defp non_list_site_entry_response do
    Jason.encode!(%{"siteEntry" => "not a list"})
  end

  defp domain_property_response do
    Jason.encode!(%{
      "siteEntry" => [
        %{"siteUrl" => "sc-domain:example.com", "permissionLevel" => "siteOwner"}
      ]
    })
  end

  # ---------------------------------------------------------------------------
  # Plug helpers
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
  # list_sites/2
  # ---------------------------------------------------------------------------

  describe "list_sites/2" do
    test "returns {:ok, sites} with a list of site maps on a 200 response with valid JSON body" do
      plug = response_plug(200, site_list_response())

      assert {:ok, sites} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
      assert is_list(sites)
      assert length(sites) == 3
    end

    test "each returned site map has :id, :name, and :account keys" do
      plug = response_plug(200, site_list_response())

      {:ok, sites} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

      for site <- sites do
        assert Map.has_key?(site, :id)
        assert Map.has_key?(site, :name)
        assert Map.has_key?(site, :account)
      end
    end

    test "extracts :id from the \"siteUrl\" field" do
      plug = response_plug(200, single_site_response())

      {:ok, [site]} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

      assert site.id == "https://example.com/"
    end

    test "extracts :name as the hostname portion of \"siteUrl\"" do
      plug = response_plug(200, single_site_response())

      {:ok, [site]} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

      assert site.name == "example.com"
    end

    test "sets :account to \"Google Search Console\" for every site" do
      plug = response_plug(200, site_list_response())

      {:ok, sites} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

      for site <- sites do
        assert site.account == "Google Search Console"
      end
    end

    test "returns {:ok, []} when \"siteEntry\" is present but empty" do
      plug = response_plug(200, empty_site_entry_response())

      assert {:ok, []} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
    end

    test "returns {:ok, []} when the response body has no \"siteEntry\" key" do
      plug = response_plug(200, no_site_entry_response())

      assert {:ok, []} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
    end

    test "returns {:ok, []} when \"siteEntry\" is present but not a list" do
      plug = response_plug(200, non_list_site_entry_response())

      assert {:ok, []} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
    end

    test "falls back :name to the raw siteUrl when hostname cannot be parsed from the URL" do
      plug = response_plug(200, domain_property_response())

      {:ok, [site]} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

      # "sc-domain:example.com" has no host in URI parsing; falls back to raw siteUrl
      assert site.id == "sc-domain:example.com"
      assert site.name == "sc-domain:example.com"
    end

    test "returns {:error, :api_disabled} on a 403 response" do
      plug = response_plug(403, ~s({"error":{"code":403,"message":"The caller does not have permission"}}))

      capture_log(fn ->
        assert {:error, :api_disabled} =
                 GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :unauthorized} on a 401 response" do
      plug = response_plug(401, ~s({"error":{"code":401,"message":"Request had invalid authentication credentials"}}))

      assert {:error, :unauthorized} =
               GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
    end

    test "returns {:error, :bad_request} on an unexpected HTTP status code" do
      plug = response_plug(500, ~s({"error":"internal server error"}))

      capture_log(fn ->
        assert {:error, :bad_request} =
                 GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
      end)
    end

    test "returns {:error, :malformed_response} on a 200 response with a non-JSON binary body" do
      plug = response_plug(200, "this is not json{{{{")

      assert {:error, :malformed_response} =
               GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
    end

    test "returns {:error, {:network_error, message}} when the HTTP request raises an exception" do
      plug = raising_plug(%RuntimeError{message: "connection refused"})

      capture_log(fn ->
        assert {:error, {:network_error, message}} =
                 GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

        assert is_binary(message)
      end)
    end

    test "accepts an :http_plug option for test injection without making real HTTP calls" do
      test_pid = self()
      plug = capture_request_plug(test_pid, site_list_response())

      GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)

      assert_receive {:request, _conn}
    end

    test "handles 200 response with binary JSON body by decoding before extracting sites" do
      # The plug sends raw binary JSON; verify the module decodes it correctly
      plug = response_plug(200, site_list_response())

      assert {:ok, sites} = GoogleSearchConsoleSites.list_sites(valid_integration(), http_plug: plug)
      assert length(sites) == 3
      assert Enum.all?(sites, &is_map/1)
    end
  end
end
