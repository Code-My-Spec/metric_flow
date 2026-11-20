defmodule MetricFlowWeb.AgencyLive.AgencySettingsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.AgenciesFixtures
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope

  describe "/app/agency/settings Anderson BI layout" do
    test "wraps the page in an Anderson BI column that cannot scroll sideways at 390px", %{
      conn: conn
    } do
      user = user_fixture()
      _account = account_with_member_fixture(user, :owner)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/app/agency/settings")

      doc = Floki.parse_document!(html)

      assert [root] = Floki.find(doc, "[data-role='agency-settings-root']")
      class = root |> Floki.attribute("class") |> List.first() || ""

      assert class =~ "overflow-x-hidden",
             "root column must carry overflow-x-hidden so nothing scrolls sideways at 390px; got: #{class}"

      assert class =~ ~r/\bmax-w-/,
             "root column must be width-capped (max-w-*) so desktop doesn't stretch; got: #{class}"
    end

    test "leads with a single h1 inside the agency-settings-root", %{conn: conn} do
      user = user_fixture()
      _account = account_with_member_fixture(user, :owner)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/app/agency/settings")

      doc = Floki.parse_document!(html)

      h1s =
        doc
        |> Floki.find("[data-role='agency-settings-root'] h1")
        |> Enum.map(&Floki.text/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      assert length(h1s) == 1,
             "expected exactly one h1 inside the agency-settings-root, got: #{inspect(h1s)}"
    end

    test "renders auto-enrollment and white-label each as its own Anderson BI card", %{conn: conn} do
      user = user_fixture()
      _account = account_with_member_fixture(user, :owner)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/app/agency/settings")

      doc = Floki.parse_document!(html)

      assert [auto | _] =
               Floki.find(
                 doc,
                 "[data-role='agency-settings-root'] [data-role='agency-auto-enrollment']"
               )

      assert [wl | _] =
               Floki.find(
                 doc,
                 "[data-role='agency-settings-root'] [data-role='agency-white-label']"
               )

      for {node, label} <- [{auto, "auto-enrollment"}, {wl, "white-label"}] do
        class = node |> Floki.attribute("class") |> List.first() || ""

        for token <- ["rounded-box", "border", "bg-base-200"] do
          assert class =~ token,
                 "#{label} section is missing Anderson BI card token #{inspect(token)}; got: #{class}"
        end
      end
    end

    test "saving auto-enrollment still works after the pass", %{conn: conn} do
      user = user_fixture()
      account = account_with_member_fixture(user, :owner)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/app/agency/settings")

      html =
        lv
        |> form("form#auto-enrollment-form", %{
          "auto_enrollment" => %{
            "domain" => "andersonthefish.com",
            "default_access_level" => "account_manager"
          }
        })
        |> render_submit()

      assert html =~ "Auto-enrollment enabled"

      scope = Scope.for_user(user)
      rule = Agencies.get_auto_enrollment_rule(scope, account.id)
      assert rule.email_domain == "andersonthefish.com"
      assert rule.default_access_level == :account_manager
    end

    test "saving white-label still works after the pass", %{conn: conn} do
      user = user_fixture()
      account = account_with_member_fixture(user, :owner)
      conn = log_in_user(conn, user)

      unique = System.unique_integer([:positive])

      {:ok, lv, _html} = live(conn, ~p"/app/agency/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "anderson-#{unique}",
            "logo_url" => "https://example.com/logo.png",
            "primary_color" => "#0BAAC8",
            "secondary_color" => "#3DC0AA"
          }
        })
        |> render_submit()

      assert html =~ "White-label settings saved"

      scope = Scope.for_user(user)
      config = Agencies.get_white_label_config(scope, account.id)
      assert config.subdomain == "anderson-#{unique}"
    end
  end
end
