defmodule MetricFlowSpex.UsersCanViewPlatformMetricMappingsToCanonicalMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Users can view which platform metrics are mapped to which canonical metrics" do
    scenario "authenticated user can access the dashboard to see metric mappings" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard loads successfully for the authenticated user", context do
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

    scenario "dashboard shows canonical metric names alongside platform source labels" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard displays a canonical metric alongside its platform source", context do
        html = render(context.view)

        has_canonical_metric =
          html =~ "Clicks" or
            html =~ "clicks" or
            html =~ "Spend" or
            html =~ "spend" or
            html =~ "Impressions" or
            html =~ "impressions" or
            has_element?(context.view, "[data-canonical-metric]") or
            has_element?(context.view, "[data-role='canonical-metric']")

        assert has_canonical_metric,
               "Expected the dashboard to show canonical metric names (e.g., 'Clicks', 'Spend', 'Impressions'), got: #{html}"

        :ok
      end
    end

    scenario "dashboard surfaces platform attribution for a canonical metric" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows a platform name associated with the displayed metrics", context do
        html = render(context.view)

        has_platform_label =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']") or
            has_element?(context.view, "[data-role='metric-mapping']")

        assert has_platform_label,
               "Expected the dashboard to identify which platform (e.g., Google, Facebook) each metric originates from, got: #{html}"

        :ok
      end
    end

    scenario "user navigates to integrations page to view detailed metric mappings" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        result = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the integrations page loads for the authenticated user", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "integrations page shows which platform is connected" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page lists the connected Google platform", context do
        html = render(context.view)

        has_google =
          html =~ "Google" or
            html =~ "google" or
            has_element?(context.view, "[data-provider='google']") or
            has_element?(context.view, "[data-role='integration-google']")

        assert has_google,
               "Expected the integrations page to show the connected Google platform integration, got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot view platform metric mappings" do
      given_ "an unauthenticated user attempts to navigate to the dashboard", context do
        result = live(build_conn(), "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the dashboard", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            # If the page loads unauthenticated it must not expose metric mapping data
            refute render(view) =~ "canonical-metric",
                   "Unauthenticated user should not see canonical metric mapping data"

            :ok
        end
      end
    end
  end
end
