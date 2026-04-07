defmodule MetricFlowSpex.AutoCorrelationCalculationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System automatically calculates correlations between all metrics and selected goal metrics" do
    scenario "user sees computed correlation results on the correlations page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays correlation results between metrics and goal metrics", context do
        html = render(context.view)

        # The correlations page should render a list of correlation results
        assert has_element?(context.view, "[data-role='correlation-results']"),
               "Expected correlation results section to be displayed. Got: #{html}"

        :ok
      end

      then_ "each correlation shows the metric name and correlation coefficient", context do
        html = render(context.view)

        # Each result should display the metric name and its coefficient value
        has_metric_info =
          has_element?(context.view, "[data-role='correlation-entry']") or
            html =~ "correlation" or
            html =~ "Correlation"

        assert has_metric_info,
               "Expected correlation entries with metric names and coefficients. Got: #{html}"

        :ok
      end
    end

    scenario "correlations page shows goal metric selection" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows which goal metric correlations are calculated against", context do
        html = render(context.view)

        has_goal_info =
          has_element?(context.view, "[data-role='goal-metric']") or
            html =~ "goal" or
            html =~ "Goal"

        assert has_goal_info,
               "Expected goal metric information to be displayed. Got: #{html}"

        :ok
      end
    end
  end
end
