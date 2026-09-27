defmodule MetricFlowSpex.AgencyAdminOpensConnectStripeSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency admin opens Connect Stripe from Billing settings" do
    scenario "admin navigates to the Stripe Connect page and sees the connect action" do
      given_ :user_logged_in_as_owner

      when_ "the admin opens the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the connect action is visible", context do
        assert has_element?(context.view, "[data-role=connect-stripe]")
        {:ok, context}
      end
    end
  end
end
