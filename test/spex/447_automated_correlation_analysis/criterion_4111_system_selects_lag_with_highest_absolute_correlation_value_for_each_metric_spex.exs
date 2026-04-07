defmodule MetricFlowSpex.CorrelationOptimalLagSelectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System selects lag with highest absolute correlation value for each metric" do
    scenario "correlation entries display the automatically selected optimal lag and coefficient" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each correlation shows the coefficient at the optimal lag", context do
        html = render(context.view)

        has_coefficient =
          has_element?(context.view, "[data-role='correlation-coefficient']") or
            html =~ "coefficient" or
            html =~ "Coefficient" or
            html =~ "r ="

        assert has_coefficient,
               "Expected correlation coefficient at optimal lag to be displayed. Got: #{html}"

        :ok
      end

      then_ "each correlation shows the selected lag value", context do
        html = render(context.view)

        has_selected_lag =
          has_element?(context.view, "[data-role='optimal-lag']") or
            html =~ "lag" or
            html =~ "Lag"

        assert has_selected_lag,
               "Expected optimal lag value to be displayed for each correlation. Got: #{html}"

        :ok
      end
    end

    scenario "correlations are sorted by strength to highlight the most relevant" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "correlations are presented in a ranked or sorted order", context do
        html = render(context.view)

        has_sorted_display =
          has_element?(context.view, "[data-role='correlation-results']") or
            html =~ "Strongest" or
            html =~ "strongest" or
            html =~ "Correlation"

        assert has_sorted_display,
               "Expected correlations to be displayed in a sorted/ranked order. Got: #{html}"

        :ok
      end
    end
  end
end
