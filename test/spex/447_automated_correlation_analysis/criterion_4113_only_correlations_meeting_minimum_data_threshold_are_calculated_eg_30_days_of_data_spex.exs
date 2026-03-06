defmodule MetricFlowSpex.CorrelationMinimumDataThresholdSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Only correlations meeting minimum data threshold are calculated eg 30 days of data" do
    scenario "user sees explanation of minimum data requirement" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page explains the minimum data threshold for correlations", context do
        html = render(context.view)

        has_threshold_info =
          has_element?(context.view, "[data-role='data-threshold']") or
            html =~ "30" or
            html =~ "minimum" or
            html =~ "Minimum" or
            html =~ "enough data" or
            html =~ "insufficient"

        assert has_threshold_info,
               "Expected minimum data threshold information (e.g., 30+ days). Got: #{html}"

        :ok
      end
    end

    scenario "when insufficient data exists user sees an explanatory message" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page with no metric data", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a message about needing more data", context do
        html = render(context.view)

        has_insufficient_message =
          has_element?(context.view, "[data-role='insufficient-data']") or
            has_element?(context.view, "[data-role='no-correlations']") or
            html =~ "Not enough data" or
            html =~ "not enough data" or
            html =~ "need at least" or
            html =~ "No correlations" or
            html =~ "no correlations"

        assert has_insufficient_message,
               "Expected a message about insufficient data for correlations. Got: #{html}"

        :ok
      end
    end
  end
end
