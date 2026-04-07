defmodule MetricFlowWeb.IntegrationLive.AccountEditTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  # ---------------------------------------------------------------------------
  # mount/3
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "mounts successfully for authenticated user", %{conn: conn} do
      user = user_fixture()
      integration_fixture(user, %{provider: :google_analytics})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, _html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  # ---------------------------------------------------------------------------
  # handle_params/3
  # ---------------------------------------------------------------------------

  describe "handle_params/3" do
    test "renders edit page with platform name heading for valid provider", %{conn: conn} do
      user = user_fixture()
      integration_fixture(user, %{provider: :google_analytics})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        assert html =~ "Google Analytics"
        assert html =~ "Edit Accounts"
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "displays checkboxes for each selected account", %{conn: conn} do
      user = user_fixture()

      integration_fixture(user, %{
        provider: :google_analytics,
        provider_metadata: %{
          "selected_accounts" => ["UA-12345 (Main Site)", "GA4-67890 (App)"]
        }
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        checkboxes = lv |> element("[data-role='account-checkbox']")
        assert has_element?(lv, "[data-role='account-checkbox']")

        html = render(lv)
        assert html =~ "UA-12345 (Main Site)"
        assert html =~ "GA4-67890 (App)"
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "shows placeholder when no accounts are configured", %{conn: conn} do
      user = user_fixture()

      integration_fixture(user, %{
        provider: :google_analytics,
        provider_metadata: %{}
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        assert html =~ "No accounts configured"
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "redirects to integrations for unknown provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/totally_fake_provider/accounts/edit")

        assert_redirect(lv, ~p"/app/integrations")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event/3 ("save_account_selection")
  # ---------------------------------------------------------------------------

  describe ~s(handle_event/3 ("save_account_selection")) do
    test "flashes success message and redirects to integrations", %{conn: conn} do
      user = user_fixture()
      integration_fixture(user, %{provider: :google_analytics})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        lv |> element("[data-role='save-account-selection']") |> render_click()

        assert_redirect(lv, ~p"/app/integrations")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  # ---------------------------------------------------------------------------
  # render/1
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "renders account checkboxes with data-role attribute", %{conn: conn} do
      user = user_fixture()
      integration_fixture(user, %{provider: :google_analytics})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        assert has_element?(lv, "[data-role='account-checkbox']")
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "renders save button", %{conn: conn} do
      user = user_fixture()
      integration_fixture(user, %{provider: :google_analytics})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        assert has_element?(lv, "[data-role='save-account-selection']")
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "renders back link to integrations", %{conn: conn} do
      user = user_fixture()
      integration_fixture(user, %{provider: :google_analytics})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/google_analytics/accounts/edit")

        assert html =~ "Back to integrations"
        assert html =~ "/app/integrations"
        send(self(), :done)
      end)

      assert_receive :done
    end
  end
end
