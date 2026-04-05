defmodule MetricFlowSpex.UsersCanCancelSubscriptionFromAccountSettingsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Users can cancel their subscription from account settings" do
    scenario "subscribed user sees cancel option in account settings" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a cancel subscription option for subscribed users", context do
        html = render(context.view)
        assert html =~ "Cancel" or html =~ "cancel"
        :ok
      end
    end
  end
end
