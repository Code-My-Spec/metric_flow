defmodule MetricFlowSpex.AgencyAffiliatedUserDoesNotSeeThisCheckoutFlowSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency-affiliated user does not see this checkout flow" do
    scenario "a user belonging to an agency account views subscription options" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_agency_plan)

      when_ "they view subscription options", context do
        {:ok, view, html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "they are directed to their agency's billing rather than this direct-checkout flow", context do
        assert context.html =~ "Agency Pro Plan"
        refute context.html =~ "MetricFlow Pro"
        {:ok, context}
      end
    end
  end
end
