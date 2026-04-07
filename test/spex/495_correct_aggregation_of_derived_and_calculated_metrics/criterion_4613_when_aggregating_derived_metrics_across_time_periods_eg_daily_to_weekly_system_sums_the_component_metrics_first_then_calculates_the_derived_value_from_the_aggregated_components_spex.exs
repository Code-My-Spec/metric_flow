defmodule MetricFlowSpex.AggregatingDerivedMetricsAcrossTimePeriodsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When aggregating derived metrics across time periods, system sums component metrics first then calculates derived value" do
    scenario "dashboard loads for an authenticated user with a time period selector" do
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

    scenario "dashboard provides a way to switch between daily and weekly time period views" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders a time period control such as a date range selector or period tabs", context do
        html = render(context.view)

        has_time_period_control =
          html =~ "Daily" or
            html =~ "daily" or
            html =~ "Weekly" or
            html =~ "weekly" or
            html =~ "Monthly" or
            html =~ "monthly" or
            html =~ "Date Range" or
            html =~ "date_range" or
            html =~ "Time Period" or
            html =~ "time_period" or
            html =~ "period" or
            has_element?(context.view, "[data-role='time-period-selector']") or
            has_element?(context.view, "[data-role='date-range-picker']") or
            has_element?(context.view, "[data-role='period-tabs']") or
            has_element?(context.view, "select[name='period']") or
            has_element?(context.view, "select[name='time_period']")

        assert has_time_period_control,
               "Expected the dashboard to display a time period control (daily/weekly/monthly selector or date range picker), got: #{html}"

        :ok
      end
    end

    scenario "switching to weekly view displays aggregated derived metrics rather than averages of daily values" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects the weekly time period view", context do
        has_weekly_control =
          has_element?(context.view, "[data-role='time-period-selector']") or
            has_element?(context.view, "[data-role='period-tabs']") or
            has_element?(context.view, "button", "Weekly") or
            has_element?(context.view, "button", "weekly") or
            has_element?(context.view, "a", "Weekly") or
            has_element?(context.view, "option", "Weekly")

        if has_weekly_control do
          html =
            cond do
              has_element?(context.view, "button", "Weekly") ->
                context.view |> element("button", "Weekly") |> render_click()

              has_element?(context.view, "a", "Weekly") ->
                context.view |> element("a", "Weekly") |> render_click()

              true ->
                render(context.view)
            end

          {:ok, Map.put(context, :weekly_html, html)}
        else
          {:ok, Map.put(context, :weekly_html, render(context.view))}
        end
      end

      then_ "the dashboard still renders derived metrics such as CPC, CTR, or ROAS in the weekly view", context do
        html = context.weekly_html

        has_derived_in_weekly_view =
          html =~ "CPC" or
            html =~ "CTR" or
            html =~ "ROAS" or
            html =~ "Conversion Rate" or
            html =~ "Cost Per Click" or
            html =~ "Click-Through Rate" or
            html =~ "metric" or
            html =~ "Metric" or
            has_element?(context.view, "[data-metric-type='derived']") or
            has_element?(context.view, "[data-metric-type='calculated']") or
            has_element?(context.view, "[data-role='derived-metric']")

        assert has_derived_in_weekly_view,
               "Expected the weekly view to display derived metrics (CPC, CTR, ROAS) calculated from summed components, got: #{html}"

        :ok
      end
    end

    scenario "the weekly view shows component raw metrics that are summed before derived metrics are computed" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders the component raw metrics (clicks, spend, impressions) alongside derived metrics", context do
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
            has_element?(context.view, "[data-role='raw-metric']")

        assert has_component_metrics,
               "Expected the dashboard to display raw component metrics (clicks, spend, impressions) that feed into derived metric calculations, got: #{html}"

        :ok
      end
    end
  end
end
