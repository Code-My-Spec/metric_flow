defmodule MetricFlowSpex.NonAdminCannotInitiateStripeConnectSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Non-admin agency member cannot initiate Stripe connect", criterion: 470 do
    scenario "a non-admin member has no connect action available to them" do
      given_ :user_logged_in_as_owner
      given_ :agency_member_registered

      when_ "the non-admin member opens the Stripe Connect page", context do
        {:ok, view, _html} = live(context.member_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the non-admin member cannot initiate Stripe connect", context do
        refute has_element?(context.view, "[data-role=connect-stripe]")
        {:ok, context}
      end
    end
  end
end
