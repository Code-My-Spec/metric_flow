defmodule MetricFlowSpex.Story75.Criterion1078Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1078 — The old /reports and /visualizations pages are
  removed and no longer exist as independent destinations.

  Implemented as a redirect to /app/dashboards rather than a literal 404
  (confirmed live by main, journey 66a06609) -- /visualizations/new and
  /visualizations/:id/edit stay routed and untouched for Story 29's
  single-chart Vega-Lite editor, which this story does not retire.

  Needs an active subscription: a free/unpaid user hitting /visualizations
  is paywall-gated first (redirected to /app/subscriptions/checkout, story
  45) before ever reaching this retirement redirect -- that's a different,
  earlier check on the same route, not something this criterion covers.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "The old reports page is gone", criterion: 1078 do
    scenario "/reports and /visualizations redirect to the dashboards list, with no nav links" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)

      when_ "anyone requests /reports or /visualizations", context do
        reports_result = live(context.owner_conn, ~p"/app/reports")
        visualizations_result = live(context.owner_conn, ~p"/app/visualizations")

        {:ok,
         Map.merge(context, %{
           reports_result: reports_result,
           visualizations_result: visualizations_result
         })}
      end

      then_ "the app sends them to the dashboards list instead", context do
        assert {:error, {:redirect, %{to: "/app/dashboards"}}} = context.reports_result
        assert {:error, {:redirect, %{to: "/app/dashboards"}}} = context.visualizations_result
        {:ok, context}
      end

      then_ "no navigation links to them", context do
        {:ok, _view, html} = live(context.owner_conn, ~p"/app/dashboards")
        refute html =~ ~s(href="/app/reports")
        refute html =~ ~s(href="/app/visualizations")
        {:ok, context}
      end
    end
  end
end
