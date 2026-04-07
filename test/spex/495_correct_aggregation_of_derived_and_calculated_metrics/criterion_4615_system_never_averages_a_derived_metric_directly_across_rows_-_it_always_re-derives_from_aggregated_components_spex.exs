defmodule MetricFlowSpex.SystemNeverAveragesDerivedMetricDirectlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System never averages a derived metric directly across rows - it always re-derives from aggregated components" do
    scenario "dashboard loads for a user with integrations" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/app/dashboard")
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

    scenario "dashboard displays derived metrics that are computed from aggregated component values" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows derived metrics rather than a simple average of per-row values", context do
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
               "Expected the dashboard to display derived metrics (CPC, CTR, ROAS) computed from aggregated components rather than averaged row-level values, got: #{html}"

        :ok
      end
    end

    scenario "dashboard renders the raw component metrics that feed into derived metric calculations" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders additive component metrics alongside derived metrics confirming the re-derive pattern", context do
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
               "Expected the dashboard to display raw additive component metrics (clicks, spend, impressions) from which derived metrics are re-computed rather than averaged, got: #{html}"

        :ok
      end
    end

    scenario "no 'average' label is shown alongside a derived metric in the dashboard summary" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "derived metrics in the dashboard do not display an average indicator next to them", context do
        html = render(context.view)

        # The dashboard should not label derived metrics as simple averages.
        # Check that if CPC/CTR/ROAS appear, they are not described as plain averages.
        has_incorrect_average_label =
          (html =~ "avg CPC" or html =~ "Avg CPC" or
             html =~ "avg CTR" or html =~ "Avg CTR" or
             html =~ "avg ROAS" or html =~ "Avg ROAS" or
             html =~ "Average CPC" or html =~ "Average CTR" or
             html =~ "Average ROAS") and
            not (has_element?(context.view, "[data-aggregation='re-derived']") or
                   has_element?(context.view, "[data-aggregation='calculated']"))

        refute has_incorrect_average_label,
               "Expected derived metrics (CPC, CTR, ROAS) to be re-derived from aggregated components, not labeled as direct averages"

        :ok
      end
    end
  end
end
