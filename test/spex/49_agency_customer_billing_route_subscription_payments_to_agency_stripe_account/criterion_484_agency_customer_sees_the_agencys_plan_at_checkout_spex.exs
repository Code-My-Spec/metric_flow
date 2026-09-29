defmodule MetricFlowSpex.AgencyCustomerSeesTheAgencysPlanAtCheckoutSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency customer sees the agency's plan at checkout", criterion: 484 do
    scenario "an agency-affiliated customer visits checkout" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      when_ "the customer navigates to checkout", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the agency's plan is shown, with a way to subscribe to it", context do
        html = render(context.view)
        assert html =~ context.agency_plan.name
        assert html =~ "subscribe-button"
        {:ok, context}
      end
    end
  end
end
