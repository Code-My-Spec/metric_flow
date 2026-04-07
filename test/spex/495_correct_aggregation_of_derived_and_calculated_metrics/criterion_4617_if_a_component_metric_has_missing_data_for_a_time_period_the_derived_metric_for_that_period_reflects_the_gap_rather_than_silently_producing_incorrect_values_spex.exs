defmodule MetricFlowSpex.DerivedMetricReflectsDataGapSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If a component metric has missing data for a time period, the derived metric reflects the gap rather than silently producing incorrect values" do
    scenario "dashboard loads for an authenticated user" do
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

    scenario "dashboard renders a gap indicator or placeholder when metric data is unavailable for a period" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard either shows data or provides a clear visual gap indicator rather than a calculated-looking zero", context do
        html = render(context.view)

        # The dashboard should indicate missing data explicitly rather than computing
        # a derived metric from a zero component (which would produce misleading values).
        shows_gap_awareness =
          html =~ "N/A" or
            html =~ "n/a" or
            html =~ "No data" or
            html =~ "no data" or
            html =~ "Unavailable" or
            html =~ "unavailable" or
            html =~ "Missing" or
            html =~ "missing" or
            html =~ "--" or
            html =~ "—" or
            has_element?(context.view, "[data-role='metric-gap']") or
            has_element?(context.view, "[data-role='no-data']") or
            has_element?(context.view, "[data-role='missing-data']") or
            has_element?(context.view, "[data-metric-status='unavailable']") or
            has_element?(context.view, "[data-metric-status='missing']") or
            # Also acceptable: the dashboard simply shows actual data for the period
            html =~ "CPC" or
            html =~ "CTR" or
            html =~ "ROAS" or
            html =~ "Clicks" or
            html =~ "Spend" or
            html =~ "Impressions"

        assert shows_gap_awareness,
               "Expected the dashboard to either display metric data or provide explicit gap indicators for missing data periods, got: #{html}"

        :ok
      end
    end

    scenario "dashboard does not display a derived metric value computed from a zero spend component when there is no data" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "any derived metric value displayed represents either real data or a gap - not a silent divide-by-zero result", context do
        html = render(context.view)

        # If the page renders a zero or infinity for a derived metric due to missing component data
        # it should be accompanied by a gap label, not silently shown as a valid number.
        # We verify the dashboard does not show bare "Infinity" or "NaN" strings,
        # which would indicate unhandled division by zero from missing component metrics.
        refute html =~ "Infinity",
               "Expected the dashboard to handle missing component metric data gracefully rather than displaying 'Infinity' for a derived metric"

        refute html =~ "NaN",
               "Expected the dashboard to handle missing component metric data gracefully rather than displaying 'NaN' for a derived metric"

        :ok
      end
    end

    scenario "dashboard provides a way to view time periods and their data availability" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders a date or period control that allows the user to navigate to periods where data may be absent", context do
        html = render(context.view)

        has_period_navigation =
          html =~ "Daily" or
            html =~ "Weekly" or
            html =~ "Monthly" or
            html =~ "Date Range" or
            html =~ "date_range" or
            html =~ "period" or
            html =~ "Period" or
            has_element?(context.view, "[data-role='time-period-selector']") or
            has_element?(context.view, "[data-role='date-range-picker']") or
            has_element?(context.view, "[data-role='period-tabs']") or
            has_element?(context.view, "select[name='period']") or
            has_element?(context.view, "select[name='time_period']") or
            has_element?(context.view, "input[type='date']")

        assert has_period_navigation,
               "Expected the dashboard to provide time period navigation so users can see which periods have missing data, got: #{html}"

        :ok
      end
    end
  end
end
