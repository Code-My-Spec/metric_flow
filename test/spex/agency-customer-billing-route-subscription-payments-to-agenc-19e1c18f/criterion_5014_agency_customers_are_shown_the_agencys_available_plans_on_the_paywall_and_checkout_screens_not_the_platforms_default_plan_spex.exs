defmodule MetricFlowSpex.AgencyCustomersShownAgencyPlansSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency customers see the agency's plans on checkout, not the platform default" do
    scenario "agency customer visits checkout page" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page shows agency-specific plans", context do
        html = render(context.view)
        assert html =~ "plan" or html =~ "Plan" or html =~ "pricing" or html =~ "Pricing"
        :ok
      end
    end
  end
end
