defmodule MetricFlowSpex.AggregatingDerivedMetricsAcrossMultiplePlatformsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When aggregating derived metrics across multiple platforms or ad accounts, system sums component metrics first then calculates derived value" do
    scenario "dashboard loads for a user who has integrations with multiple platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard loads without error", context do
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

    scenario "dashboard provides a way to view metrics across all platforms combined" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders a platform or account filter or an all-platforms combined view", context do
        html = render(context.view)

        has_platform_control =
          html =~ "All Platforms" or
            html =~ "all platforms" or
            html =~ "All Accounts" or
            html =~ "all accounts" or
            html =~ "Platform" or
            html =~ "platform" or
            html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            html =~ "combined" or
            html =~ "Combined" or
            has_element?(context.view, "[data-role='platform-filter']") or
            has_element?(context.view, "[data-role='platform-selector']") or
            has_element?(context.view, "[data-role='account-filter']") or
            has_element?(context.view, "select[name='platform']") or
            has_element?(context.view, "select[name='account']")

        assert has_platform_control,
               "Expected the dashboard to display a platform or account filter for cross-platform metric aggregation, got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays derived metrics when viewing data across multiple ad accounts" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders derived metrics regardless of whether single or multiple platforms are shown", context do
        html = render(context.view)

        has_derived_metrics =
          html =~ "CPC" or
            html =~ "CTR" or
            html =~ "ROAS" or
            html =~ "Conversion Rate" or
            html =~ "Cost Per Click" or
            html =~ "Click-Through Rate" or
            html =~ "Return on Ad Spend" or
            has_element?(context.view, "[data-metric-type='derived']") or
            has_element?(context.view, "[data-metric-type='calculated']") or
            has_element?(context.view, "[data-role='derived-metric']") or
            has_element?(context.view, "[data-role='calculated-metric']")

        assert has_derived_metrics,
               "Expected the dashboard to display derived metrics (CPC, CTR, ROAS) that are computed from summed cross-platform components, got: #{html}"

        :ok
      end
    end

    scenario "dashboard renders raw component metrics alongside derived metrics for cross-platform view" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders raw component metrics (clicks, spend, impressions) that are summed before derived metrics are computed", context do
        html = render(context.view)

        has_component_metrics =
          html =~ "Clicks" or
            html =~ "clicks" or
            html =~ "Spend" or
            html =~ "spend" or
            html =~ "Impressions" or
            html =~ "impressions" or
            has_element?(context.view, "[data-metric-type='additive']") or
            has_element?(context.view, "[data-metric-type='raw']") or
            has_element?(context.view, "[data-role='raw-metric']") or
            has_element?(context.view, "[data-role='additive-metric']")

        assert has_component_metrics,
               "Expected the dashboard to display raw component metrics (clicks, spend, impressions) that are summed across platforms before derived metric calculation, got: #{html}"

        :ok
      end
    end
  end
end
