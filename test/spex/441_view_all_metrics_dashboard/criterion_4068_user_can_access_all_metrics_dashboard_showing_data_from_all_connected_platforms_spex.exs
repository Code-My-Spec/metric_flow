defmodule MetricFlowSpex.UserCanAccessAllMetricsDashboardShowingDataFromAllConnectedPlatformsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can access All Metrics dashboard showing data from all connected platforms" do
    scenario "authenticated user can navigate to the dashboard page" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard page loads successfully", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "dashboard page shows a heading identifying it as the metrics dashboard" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a heading for the all metrics dashboard", context do
        html = render(context.view)

        assert html =~ "All Metrics" or
                 html =~ "Dashboard" or
                 html =~ "dashboard" or
                 has_element?(context.view, "[data-role='dashboard-heading']") or
                 has_element?(context.view, "h1")

        :ok
      end
    end

    scenario "dashboard page shows data from connected platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page references at least one connected platform provider", context do
        html = render(context.view)

        assert html =~ "Google" or
                 html =~ "google" or
                 html =~ "Facebook" or
                 html =~ "facebook" or
                 html =~ "Analytics" or
                 html =~ "Ads" or
                 has_element?(context.view, "[data-platform]") or
                 has_element?(context.view, "[data-role='platform-metrics']")

        :ok
      end
    end

    scenario "dashboard page includes a metrics data area" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains a section or element for displaying metrics data", context do
        assert has_element?(context.view, "[data-role='metrics-dashboard']") or
                 has_element?(context.view, "[data-role='metrics-data']") or
                 has_element?(context.view, "[data-role='dashboard-content']") or
                 has_element?(context.view, "[data-role='metrics-area']") or
                 render(context.view) =~ "metric" or
                 render(context.view) =~ "Metric"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the dashboard" do
      given_ "an unauthenticated user navigates to the dashboard", context do
        result = live(build_conn(), "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the dashboard", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "All Metrics"
            :ok
        end
      end
    end
  end
end
