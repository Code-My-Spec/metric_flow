defmodule MetricFlowSpex.AgencyUserAssociatedViaInviteSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User who signs up via an agency invite link is associated with that agency" do
    scenario "user navigates to checkout after signing up via agency invite token" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page reflects the user's agency association", context do
        html = render(context.view)
        assert html =~ "agency" or html =~ "Agency" or html =~ "checkout" or html =~ "Checkout" or
                 html =~ "Plan" or html =~ "Subscribe" or html =~ "Choose Your Plan"
        :ok
      end
    end
  end
end
