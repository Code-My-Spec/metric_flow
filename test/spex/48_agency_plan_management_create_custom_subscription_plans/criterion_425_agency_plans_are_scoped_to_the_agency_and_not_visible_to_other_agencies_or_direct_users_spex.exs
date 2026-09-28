defmodule MetricFlowSpex.AgencyPlansScopedToAgencySpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency plans are scoped to the agency", criterion: 425 do
    scenario "direct user cannot see agency plans" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "only platform plans are visible, not other agency plans", context do
        html = render(context.view)
        refute html =~ "Agency Custom Plan"
        {:ok, context}
      end
    end
  end
end
