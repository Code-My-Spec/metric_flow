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
      agency = account_fixture(%{type: "team"})

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
      agency = account_fixture(%{type: "team"})

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
  end
end
