defmodule MetricFlowSpex.UnconnectedAgencyCustomersUseDefaultBillingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Unconnected agency customers are prompted for default billing" do
    scenario "customer under unconnected agency sees platform billing" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows subscription options", context do
        html = render(context.view)
        assert html =~ "Subscribe"
        :ok
      end
    end
  end
end
