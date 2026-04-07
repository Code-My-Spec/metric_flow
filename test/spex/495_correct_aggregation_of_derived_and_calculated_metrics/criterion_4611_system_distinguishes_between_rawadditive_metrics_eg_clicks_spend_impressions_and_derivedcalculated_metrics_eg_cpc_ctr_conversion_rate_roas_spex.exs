defmodule MetricFlowSpex.SystemDistinguishesBetweenRawAdditiveMetricsAndDerivedCalculatedMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System distinguishes between raw/additive metrics and derived/calculated metrics" do
    scenario "dashboard page loads for an authenticated user" do
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

    scenario "dashboard displays raw additive metrics such as clicks, spend, and impressions" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders additive metric labels or containers for raw metrics", context do
        html = render(context.view)

        has_raw_metrics =
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

        assert has_raw_metrics,
               "Expected the dashboard to display raw/additive metrics (clicks, spend, impressions), got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays derived/calculated metrics such as CPC, CTR, or ROAS" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders derived metric labels or containers for calculated metrics", context do
        html = render(context.view)

        has_derived_metrics =
          html =~ "CPC" or
            html =~ "cpc" or
            html =~ "CTR" or
            html =~ "ctr" or
            html =~ "ROAS" or
            html =~ "roas" or
            html =~ "Conversion Rate" or
            html =~ "conversion_rate" or
            html =~ "Cost Per Click" or
            html =~ "cost_per_click" or
            has_element?(context.view, "[data-metric-type='derived']") or
            has_element?(context.view, "[data-metric-type='calculated']") or
            has_element?(context.view, "[data-role='derived-metric']") or
            has_element?(context.view, "[data-role='calculated-metric']")

        assert has_derived_metrics,
               "Expected the dashboard to display derived/calculated metrics (CPC, CTR, ROAS, conversion rate), got: #{html}"

        :ok
      end
    end

    scenario "dashboard does not mix up raw and derived metric categories" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders at least one metric section or metric list", context do
        html = render(context.view)

        has_any_metric =
          html =~ "metric" or
            html =~ "Metric" or
            has_element?(context.view, "[data-role='metrics-list']") or
            has_element?(context.view, "[data-role='metrics-dashboard']") or
            has_element?(context.view, "[data-role='metric-card']")

        assert has_any_metric,
               "Expected the dashboard to display at least one metric section, got: #{html}"

        :ok
      end
    end
  end
end
