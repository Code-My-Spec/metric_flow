defmodule MetricFlowSpex.CorrelationDailyAggregatedDataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Correlation calculations use daily aggregated data" do
    scenario "user sees that correlations are based on daily data" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page indicates correlations use daily aggregated data", context do
        html = render(context.view)

        has_daily_info =
          has_element?(context.view, "[data-role='data-granularity']") or
            html =~ "daily" or
            html =~ "Daily" or
            html =~ "per day" or
            html =~ "day-level"

        assert has_daily_info,
               "Expected indication that correlations use daily aggregated data. Got: #{html}"

        :ok
      end
    end

    scenario "correlation results display the date range used for calculation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the data window used for calculations", context do
        html = render(context.view)

        has_date_range =
          has_element?(context.view, "[data-role='data-window']") or
            has_element?(context.view, "[data-role='date-range']") or
            html =~ "days of data" or
            html =~ "data points"

        assert has_date_range,
               "Expected data window or date range information. Got: #{html}"

        :ok
      end
    end
  end
end
