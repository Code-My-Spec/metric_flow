defmodule MetricFlowWeb.Plugs.WhiteLabelTest do
  use MetricFlowTest.ConnCase, async: true

  import MetricFlowTest.AgenciesFixtures

  alias MetricFlowWeb.Plugs.WhiteLabel

  # ---------------------------------------------------------------------------
  # init/1
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [foo: :bar]
      assert WhiteLabel.init(opts) == opts
    end
  end

  # ---------------------------------------------------------------------------
  # call/2
  # ---------------------------------------------------------------------------

  describe "call/2" do
    setup %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})

      %{conn: conn}
    end

    test "sets white_label_config to nil for bare domain (no subdomain)", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "metric-flow.app")
        |> WhiteLabel.call([])

      assert get_session(conn, :white_label_config) == nil
    end

    test "sets white_label_config to nil for unknown subdomain", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "unknown-agency.metric-flow.app")
        |> WhiteLabel.call([])

      assert get_session(conn, :white_label_config) == nil
    end

    test "loads config into session for matching subdomain", %{conn: conn} do
      agency = account_fixture(%{type: "agency"})

      config =
        white_label_config_fixture(agency.id, %{
          subdomain: "acme",
          logo_url: "https://acme.com/logo.png",
          primary_color: "#AA0000",
          secondary_color: "#00BB00"
        })

      conn =
        conn
        |> Map.put(:host, "acme.metric-flow.app")
        |> WhiteLabel.call([])

      session_config = get_session(conn, :white_label_config)
      assert session_config != nil
      assert session_config.subdomain == config.subdomain
    end

    test "session config contains subdomain, logo_url, primary_color, secondary_color", %{conn: conn} do
      agency = account_fixture(%{type: "agency"})

      white_label_config_fixture(agency.id, %{
        subdomain: "brandco",
        logo_url: "https://brandco.com/logo.png",
        primary_color: "#112233",
        secondary_color: "#445566"
      })

      conn =
        conn
        |> Map.put(:host, "brandco.metric-flow.app")
        |> WhiteLabel.call([])

      session_config = get_session(conn, :white_label_config)
      assert session_config.subdomain == "brandco"
      assert session_config.logo_url == "https://brandco.com/logo.png"
      assert session_config.primary_color == "#112233"
      assert session_config.secondary_color == "#445566"
    end

    test "handles localhost and IP addresses gracefully (no subdomain extracted)", %{conn: conn} do
      conn_localhost =
        conn
        |> Map.put(:host, "localhost")
        |> WhiteLabel.call([])

      assert get_session(conn_localhost, :white_label_config) == nil

      conn_ip =
        conn
        |> Map.put(:host, "192.168.1.1")
        |> WhiteLabel.call([])

      assert get_session(conn_ip, :white_label_config) == nil
    end

    test "resolves verified custom domain to white-label config", %{conn: conn} do
      agency = account_fixture(%{type: "agency"})

      config =
        white_label_config_fixture(agency.id, %{
          subdomain: "acme-cd",
          custom_domain: "analytics.example.com",
          primary_color: "#AA0000"
        })

      # Manually set verified_at since the fixture doesn't set it
      config
      |> Ecto.Changeset.change(custom_domain_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> MetricFlow.Repo.update!()

      conn =
        conn
        |> Map.put(:host, "analytics.example.com")
        |> WhiteLabel.call([])

      session_config = get_session(conn, :white_label_config)
      assert session_config != nil
      assert session_config.custom_domain == "analytics.example.com"
      assert session_config.primary_color == "#AA0000"
    end

    test "does NOT resolve unverified custom domain", %{conn: conn} do
      agency = account_fixture(%{type: "agency"})

      white_label_config_fixture(agency.id, %{
        subdomain: "acme-unv",
        custom_domain: "unverified.example.com"
      })

      conn =
        conn
        |> Map.put(:host, "unverified.example.com")
        |> WhiteLabel.call([])

      assert get_session(conn, :white_label_config) == nil
    end

    test "subdomain extraction still works alongside custom domains", %{conn: conn} do
      agency = account_fixture(%{type: "agency"})

      white_label_config_fixture(agency.id, %{
        subdomain: "legacy-sub",
        custom_domain: "custom.example.com"
      })

      conn =
        conn
        |> Map.put(:host, "legacy-sub.metric-flow.app")
        |> WhiteLabel.call([])

      session_config = get_session(conn, :white_label_config)
      assert session_config != nil
      assert session_config.subdomain == "legacy-sub"
    end

    test "metric-flow.app hosts skip custom domain lookup", %{conn: conn} do
      # Even if "metric-flow.app" matched a custom_domain in the DB,
      # it should not be looked up — only subdomain extraction applies
      conn =
        conn
        |> Map.put(:host, "metric-flow.app")
        |> WhiteLabel.call([])

      assert get_session(conn, :white_label_config) == nil
    end

    test "session config includes custom_domain field", %{conn: conn} do
      agency = account_fixture(%{type: "agency"})

      config =
        white_label_config_fixture(agency.id, %{
          subdomain: "with-cd",
          custom_domain: "branded.example.com",
          logo_url: "https://branded.com/logo.png",
          primary_color: "#112233",
          secondary_color: "#445566"
        })

      config
      |> Ecto.Changeset.change(custom_domain_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> MetricFlow.Repo.update!()

      conn =
        conn
        |> Map.put(:host, "branded.example.com")
        |> WhiteLabel.call([])

      session_config = get_session(conn, :white_label_config)
      assert session_config.custom_domain == "branded.example.com"
      assert session_config.subdomain == "with-cd"
      assert session_config.logo_url == "https://branded.com/logo.png"
    end
  end
end
