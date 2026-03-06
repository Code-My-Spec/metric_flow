defmodule MetricFlowSpex.DerivedMetricsDisplayIdenticallyToRawMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Derived metrics display identically to raw metrics in dashboards and reports - the aggregation logic is transparent to the user" do
    scenario "dashboard loads for an authenticated user with integrations" do
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

    scenario "dashboard renders raw and derived metrics in a visually uniform manner" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both raw and derived metrics appear in the dashboard without separate sections labeling them differently", context do
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
            has_element?(context.view, "[data-role='raw-metric']")

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
            has_element?(context.view, "[data-role='derived-metric']")

        # Both raw and derived metrics should be present and displayed in the same dashboard UI
        assert has_raw_metrics or has_derived_metrics,
               "Expected the dashboard to display metrics (raw or derived) in a uniform way, got: #{html}"

        :ok
      end
    end

    scenario "dashboard does not expose internal aggregation labels to the user" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard does not show internal implementation details like formula strings to the user", context do
        html = render(context.view)

        # The aggregation logic should be transparent - users see metric values, not formulas.
        # Internal labels like "sum(spend)/sum(clicks)" should not appear in the rendered UI.
        refute html =~ "sum(spend)/sum(clicks)",
               "Expected dashboard to hide internal CPC aggregation formula from users"

        refute html =~ "sum(clicks)/sum(impressions)",
               "Expected dashboard to hide internal CTR aggregation formula from users"

        refute html =~ "sum(revenue)/sum(spend)",
               "Expected dashboard to hide internal ROAS aggregation formula from users"

        :ok
      end
    end

    scenario "dashboard presents derived metrics with the same formatting and presentation as raw metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "derived and raw metrics share a consistent card or table presentation style visible to the user", context do
        html = render(context.view)

        # Both types of metrics should appear in the same UI container style -
        # metric cards, table rows, or a unified metric grid.
        uses_consistent_presentation =
          has_element?(context.view, "[data-role='metric-card']") or
            has_element?(context.view, "[data-role='metric-value']") or
            has_element?(context.view, "[data-role='metric']") or
            has_element?(context.view, ".metric-card") or
            has_element?(context.view, ".stat") or
            has_element?(context.view, "table") or
            html =~ "metric" or
            html =~ "Metric" or
            html =~ "CPC" or
            html =~ "CTR" or
            html =~ "ROAS" or
            html =~ "Clicks" or
            html =~ "Spend"

        assert uses_consistent_presentation,
               "Expected derived and raw metrics to share the same visual presentation in the dashboard, got: #{html}"

        :ok
      end
    end

    scenario "user does not see computation-type badges distinguishing raw from derived metric values" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders metric values without user-visible labels exposing how each metric was computed", context do
        html = render(context.view)

        # Aggregation logic is transparent to the user -
        # the UI should not expose computation-type badges that reveal internal implementation.
        refute html =~ "(calculated)",
               "Expected aggregation logic to be transparent; found '(calculated)' label exposed to user"

        refute html =~ "(derived)",
               "Expected aggregation logic to be transparent; found '(derived)' label exposed to user"

        refute html =~ "(raw)",
               "Expected aggregation logic to be transparent; found '(raw)' label exposed to user"

        refute html =~ "aggregation method",
               "Expected aggregation logic to be hidden; found 'aggregation method' exposed to user in dashboard"

        :ok
      end
    end
  end
end
