defmodule MetricFlowSpex.FreeUsersAccessDashboardAndIntegrationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Free users can access the dashboard and all integrations pages without restriction" do
    scenario "free user navigates to the dashboard without seeing a paywall" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the dashboard", context do
        result = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard loads successfully without a paywall or upgrade prompt", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)
            refute html =~ "upgrade" or html =~ "Upgrade" or
                     has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected no paywall on /dashboard for free user. Got: #{html}"
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "free user navigates to the integrations page without seeing a paywall" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the integrations page", context do
        result = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the integrations page loads successfully without a paywall or upgrade prompt", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)
            refute has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected no paywall on /integrations for free user. Got: #{html}"
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was live-redirected to #{path}")
        end
      end
    end
  end
end
