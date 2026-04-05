defmodule MetricFlowSpex.UsersCanViewCurrentPlanAndBillingStatusSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Users can view their current plan and billing status in account settings" do
    scenario "free user sees their plan status as Free on account settings" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the current plan and billing status", context do
        html = render(context.view)
        assert html =~ "Plan" or html =~ "Subscription"
        assert html =~ "Free" or html =~ "Upgrade"
        :ok
      end
    end
  end
end
