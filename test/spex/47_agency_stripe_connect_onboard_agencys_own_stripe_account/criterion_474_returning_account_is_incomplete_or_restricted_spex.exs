defmodule MetricFlowSpex.ReturningAccountIsRestrictedSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Returning account is incomplete or restricted", criterion: 474 do
    scenario "agency with an incomplete Stripe account is shown as restricted" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_incomplete_stripe_connect

      when_ "the admin views the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the restricted status", context do
        html = render(context.view)
        assert html =~ "Restricted"
        {:ok, context}
      end
    end
  end
end
