defmodule MetricFlowSpex.Criterion859UserAccessesCorrelationAnalysisFromMainNavigationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User accesses correlation analysis from main navigation", criterion: 859 do
    scenario "a user browsing the application selects correlation analysis from the main navigation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user browsing the application", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select correlation analysis from the main navigation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they are taken to the correlation analysis view", context do
        html = render(context.view)
        assert html =~ "Which metrics drive your goal"
        {:ok, context}
      end
    end
  end
end
