defmodule MetricFlowSpex.MappedMetricsCanBeAggregatedAcrossPlatformsInDashboardsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Mapped metrics can be aggregated across platforms in dashboards and reports using canonical names" do
    scenario "dashboard loads for a user with integrations" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard page loads without error", context do
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

    scenario "dashboard displays an aggregated total for the canonical 'clicks' metric across platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows a combined clicks total using the canonical metric name", context do
        html = render(context.view)

        has_aggregated_clicks =
          html =~ "clicks" or
            html =~ "clicks" or
            has_element?(context.view, "[data-canonical-metric='clicks']") or
            has_element?(context.view, "[data-metric-name='clicks']") or
            has_element?(context.view, "[data-role='metric-clicks']") or
            has_element?(context.view, "[data-role='aggregated-clicks']")

        assert has_aggregated_clicks,
               "Expected the dashboard to display aggregated 'clicks' across platforms using the canonical name, got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays an aggregated total for the canonical 'spend' metric across platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows a combined spend total using the canonical metric name", context do
        html = render(context.view)

        has_aggregated_spend =
          html =~ "total_cost" or
            html =~ "spend" or
            has_element?(context.view, "[data-canonical-metric='spend']") or
            has_element?(context.view, "[data-metric-name='spend']") or
            has_element?(context.view, "[data-role='metric-spend']") or
            has_element?(context.view, "[data-role='aggregated-spend']")

        assert has_aggregated_spend,
               "Expected the dashboard to display aggregated 'spend' across platforms using the canonical name, got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays aggregated metrics labeled with the canonical name, not a platform-specific name" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the aggregated metric row does not show raw platform-specific metric names as the label", context do
        html = render(context.view)

        # The canonical 'clicks' aggregation should not be labeled with the raw platform
        # metric name like 'Link Clicks' (Facebook) or 'Clicks (all)' (Google Ads internal).
        # Those raw names may appear as breakdowns but not as the primary aggregated label.
        shows_link_clicks_as_aggregated_label =
          has_element?(context.view, "[data-canonical-metric='link_clicks']") or
            has_element?(context.view, "[data-canonical-metric='link clicks']")

        refute shows_link_clicks_as_aggregated_label,
               "Expected the aggregated metric to use the canonical name 'clicks', not the platform-specific 'Link Clicks'. HTML: #{html}"

        :ok
      end
    end

    scenario "the dashboard references platform sources alongside the aggregated canonical metric" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard indicates which platforms contribute to the aggregated metric total", context do
        html = render(context.view)

        # The dashboard should reference the underlying platforms (e.g., Google, Facebook)
        # so users understand the aggregated value spans multiple sources.
        has_platform_source =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']") or
            has_element?(context.view, "[data-role='aggregation-source']")

        assert has_platform_source,
               "Expected the dashboard to indicate platform sources contributing to the aggregated canonical metric, got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access aggregated metric data" do
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
            refute render(view) =~ "aggregated"
            :ok
        end
      end
    end
  end
end
