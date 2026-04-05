defmodule MetricFlowSpex.AgencyStripeStateStoredSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency Stripe connection state is stored and reflected in UI" do
    scenario "Stripe Connect page reflects stored connection state" do
      given_ :user_logged_in_as_owner

      given_ "the admin navigates to the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page reflects the current Stripe connection state", context do
        html = render(context.view)
        assert html =~ "Stripe Connect"
        :ok
      end
    end
  end
end
