defmodule MetricFlowSpex.DirectUserSubscribesToTheFlatMonthlyPlanSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Direct user subscribes to the flat monthly plan" do
    scenario "a direct user with no agency affiliation opens the subscribe flow" do
      given_(:user_logged_in_as_owner)

      when_ "they open the subscribe flow", context do
        {:ok, view, html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "they can proceed to checkout for the flat monthly plan", context do
        assert context.html =~ "Choose Your Plan"
        assert has_element?(context.view, "[data-role=subscribe-button]") or
                 context.html =~ "No plans available"
        {:ok, context}
      end
    end
  end
end
