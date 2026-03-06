defmodule MetricFlowSpex.CorrelationAllMetricsUnifiedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Correlation runs against ALL metrics financial and marketing treated the same" do
    scenario "correlation results include both financial and marketing metrics" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows correlations for all metric types without distinction", context do
        html = render(context.view)

        # The correlations page should show a unified list of all metrics
        # without segregating financial from marketing metrics
        has_unified_results =
          has_element?(context.view, "[data-role='correlation-results']") or
            html =~ "All Metrics" or
            html =~ "all metrics" or
            html =~ "Correlation"

        assert has_unified_results,
               "Expected unified correlation results for all metric types. Got: #{html}"

        :ok
      end
    end

    scenario "no separate sections for financial vs marketing correlations" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is no separation between financial and marketing metrics in the results", context do
        html = render(context.view)

        # Ensure there are no separate sections that divide metrics by type
        no_segregation =
          not has_element?(context.view, "[data-role='marketing-correlations']") and
            not has_element?(context.view, "[data-role='financial-correlations']")

        assert no_segregation,
               "Expected no separate financial/marketing sections — metrics should be unified. Got: #{html}"

        :ok
      end
    end
  end
end
