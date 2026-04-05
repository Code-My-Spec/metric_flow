defmodule MetricFlowSpex.AgencyPlansScopedToAgencySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency plans are scoped to the agency" do
    scenario "direct user cannot see agency plans" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "only platform plans are visible, not other agency plans", context do
        html = render(context.view)
        refute html =~ "Agency Custom Plan"
        :ok
      end
    end
  end
end
