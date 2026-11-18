defmodule MetricFlowWeb.OnboardingLive.ConnectTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.IntegrationsFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp stub_options(fun) do
    Application.put_env(:metric_flow, :onboarding_options_loader, fun)
    on_exit(fn -> Application.delete_env(:metric_flow, :onboarding_options_loader) end)
  end

  describe "wizard steps" do
    test "renders the stepper and starts at Google when nothing is connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect")

      for step <- ~w(google facebook_ads quickbooks done) do
        assert has_element?(view, "#wizard-step-#{step}")
      end

      assert has_element?(view, "#wizard-step-google[data-current='true']")
      assert has_element?(view, "#not-connected-google")
    end

    test "not connected shows one Connect Google link to the bundled grant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=google")

      assert has_element?(view, "#connect-google[href^='/app/integrations/oauth/google_bundle']")
      assert render(view) =~ "Google Analytics 4"
      assert render(view) =~ "Search Console"
      assert has_element?(view, "#wizard-continue", "Skip for now")
    end

    test "Meta and QuickBooks steps link to their own OAuth flows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=facebook_ads")

      assert has_element?(
               view,
               "#connect-facebook_ads[href^='/app/integrations/oauth/facebook_ads']"
             )

      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=quickbooks")
      assert has_element?(view, "#connect-quickbooks[href^='/app/integrations/oauth/quickbooks']")
    end

    test "done step summarizes and links to the dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=done")

      assert has_element?(view, "#wizard-done", "Nothing connected yet")
      assert has_element?(view, "#open-dashboard[href='/app/dashboard']")
      assert has_element?(view, "#manage-connections[href='/app/integrations']")
    end
  end

  describe "connected Google" do
    test "shows each product's status, with unticked products as not granted",
         %{conn: conn, user: user} do
      integration_fixture(user, provider: :google_analytics)
      stub_options(fn _scope, _product -> {:ok, [%{id: "GA4-67890", name: "Main site"}]} end)

      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=google")

      assert has_element?(view, "#product-google_analytics[data-status='ready']")
      assert has_element?(view, "#product-google_ads[data-status='not_granted']")
      assert has_element?(view, "#grant-google_ads")
      assert render(view) =~ "Connected as #{user.email}"
    end

    test "loads options, saves a selection and reports syncing", %{conn: conn, user: user} do
      integration_fixture(user,
        provider: :google_search_console,
        granted_scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
        provider_metadata: %{"email" => user.email}
      )

      stub_options(fn _scope, :google_search_console ->
        {:ok,
         [
           %{id: "https://a.example/", name: "a.example"},
           %{id: "sc-domain:b.example", name: "b.example"}
         ]}
      end)

      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=google")

      assert has_element?(view, "#product-google_search_console[data-status='needs_selection']")
      render_async(view)
      assert has_element?(view, "#picker-google_search_console")

      view
      |> form("#picker-google_search_console", %{"ids" => ["sc-domain:b.example"]})
      |> render_submit()

      assert has_element?(view, "#synced-note-google_search_console")
      assert has_element?(view, "#product-google_search_console[data-status='ready']")

      saved =
        Repo.get_by!(Integration,
          user_id: user.id,
          account_id: MetricFlowTest.UsersFixtures.default_account_id(user.id),
          provider: :google_search_console
        )

      assert saved.provider_metadata["site_url"] == "sc-domain:b.example"
    end

    test "explains an empty option list", %{conn: conn, user: user} do
      integration_fixture(user,
        provider: :google_analytics,
        provider_metadata: %{"email" => user.email}
      )

      stub_options(fn _scope, _product -> {:ok, []} end)

      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=google")
      render_async(view)

      assert has_element?(view, "#options-empty-google_analytics", "No properties found")
    end

    test "shows the provider error when options can't load", %{conn: conn, user: user} do
      integration_fixture(user,
        provider: :google_analytics,
        provider_metadata: %{"email" => user.email}
      )

      stub_options(fn _scope, _product -> {:error, :api_disabled} end)

      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=google")
      render_async(view)

      assert has_element?(view, "#options-error-google_analytics", "API is disabled")
    end

    test "a sign-in the provider rejects asks to reconnect, not about roles", %{
      conn: conn,
      user: user
    } do
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)

      integration_fixture(user,
        provider: :google_analytics,
        provider_metadata: %{"email" => user.email}
      )

      stub_options(fn _scope, _product -> {:error, :unauthorized} end)

      {:ok, view, _html} = live(conn, ~p"/app/onboarding/connect?step=google")
      render_async(view)

      assert has_element?(view, "#options-error-google_analytics", "sign-in was rejected")
      refute render(view) =~ "Only account owners"

      assert has_element?(
               view,
               "#reconnect-google_analytics[href^='/app/integrations/oauth/google_bundle']"
             )
    end
  end
end
