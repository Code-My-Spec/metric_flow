defmodule MetricFlowSpex.CorrelationsDailyCalculationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Correlations are calculated daily after data sync completes" do
    scenario "user sees when correlations were last calculated" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays when correlations were last calculated", context do
        html = render(context.view)

        has_last_calculated =
          has_element?(context.view, "[data-role='last-calculated']") or
            html =~ "Last calculated" or
            html =~ "last calculated" or
            html =~ "Calculated"

        assert has_last_calculated,
               "Expected a 'last calculated' timestamp to be displayed. Got: #{html}"

        :ok
      end
    end

    scenario "user sees that correlations update daily after sync" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        conn = context.owner_conn
        {:ok, view, _html} = live(conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page indicates correlations are refreshed daily", context do
        html = render(context.view)

        has_schedule_info =
          has_element?(context.view, "[data-role='calculation-schedule']") or
            html =~ "daily" or
            html =~ "Daily" or
            html =~ "after sync"

        assert has_schedule_info,
               "Expected daily calculation schedule information. Got: #{html}"

        :ok
      end
    end
  end
end
