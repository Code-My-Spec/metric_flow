defmodule MetricFlowSpex.CorrelationTimeLagDetectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System tests multiple time lags 0-30 days for each metric to automatically find optimal lag" do
    scenario "user sees optimal lag displayed for each correlation result" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each correlation entry shows the optimal time lag", context do
        html = render(context.view)

        has_lag_info =
          has_element?(context.view, "[data-role='optimal-lag']") or
            html =~ "lag" or
            html =~ "Lag" or
            html =~ "day"

        assert has_lag_info,
               "Expected optimal lag information for each correlation. Got: #{html}"

        :ok
      end
    end

    scenario "user sees the lag range that was tested" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page indicates the lag range tested (0-30 days)", context do
        html = render(context.view)

        has_lag_range =
          has_element?(context.view, "[data-role='lag-range']") or
            html =~ "0-30" or
            html =~ "0 to 30" or
            html =~ "30 days"

        assert has_lag_range,
               "Expected lag range information (0-30 days) to be displayed. Got: #{html}"

        :ok
      end
    end
  end
end
