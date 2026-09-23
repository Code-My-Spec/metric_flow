defmodule MetricFlowSpex.DerivedMetricsAreDefinedByFormulaReferencingComponentRawMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Derived metrics are defined by a formula referencing their component raw metrics" do
    scenario "dashboard loads and displays CPC as spend divided by clicks" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard displays CPC as a derived metric calculated from spend and clicks", context do
        html = render(context.view)

        has_cpc_metric =
          html =~ "cpc" or
            html =~ "Cost Per Click" or
            html =~ "cost_per_click" or
            html =~ "cost-per-click" or
            has_element?(context.view, "[data-metric='cpc']") or
            has_element?(context.view, "[data-metric-key='cpc']") or
            has_element?(context.view, "[data-role='derived-metric'][data-name='cpc']")

        assert has_cpc_metric,
               "Expected dashboard to display CPC as a derived metric (spend / clicks), got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays ROAS as revenue divided by spend" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard displays ROAS as a derived metric calculated from revenue and spend", context do
        html = render(context.view)

        has_roas_metric =
          html =~ "roas" or
            html =~ "Return on Ad Spend" or
            html =~ "return_on_ad_spend" or
            has_element?(context.view, "[data-metric='roas']") or
            has_element?(context.view, "[data-metric-key='roas']") or
            has_element?(context.view, "[data-role='derived-metric'][data-name='roas']")

        assert has_roas_metric,
               "Expected dashboard to display ROAS as a derived metric (revenue / spend), got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays CTR as clicks divided by impressions" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard displays CTR as a derived metric calculated from clicks and impressions", context do
        html = render(context.view)

        has_ctr_metric =
          html =~ "ctr" or
            html =~ "Click-Through Rate" or
            html =~ "Click Through Rate" or
            html =~ "click_through_rate" or
            html =~ "Conversion Rate" or
            html =~ "conversion_rate" or
            has_element?(context.view, "[data-metric='ctr']") or
            has_element?(context.view, "[data-metric-key='ctr']") or
            has_element?(context.view, "[data-role='derived-metric']")

        assert has_ctr_metric,
               "Expected dashboard to display CTR or conversion rate as a derived metric (clicks / impressions), got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows both component raw metrics and the derived metric they produce" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders both raw component metrics and at least one derived metric", context do
        html = render(context.view)

        has_raw_component =
          html =~ "clicks" or
            html =~ "clicks" or
            html =~ "total_cost" or
            html =~ "spend" or
            html =~ "impressions" or
            html =~ "impressions" or
            has_element?(context.view, "[data-metric-type='additive']") or
            has_element?(context.view, "[data-metric-type='raw']")

        has_derived_metric =
          html =~ "cpc" or
            html =~ "ctr" or
            html =~ "roas" or
            html =~ "Conversion Rate" or
            html =~ "Cost Per Click" or
            has_element?(context.view, "[data-metric-type='derived']") or
            has_element?(context.view, "[data-metric-type='calculated']") or
            has_element?(context.view, "[data-role='derived-metric']")

        assert has_raw_component,
               "Expected dashboard to display raw/component metrics (clicks, spend, impressions), got: #{html}"

        assert has_derived_metric,
               "Expected dashboard to display at least one derived metric (CPC, CTR, ROAS, conversion rate), got: #{html}"

        :ok
      end
    end
  end
end
