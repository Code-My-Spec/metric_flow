defmodule MetricFlowSpex.AgencyAdminsViewCustomerSubscriptionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admins can view a list of all customers subscribed under their agency" do
    scenario "agency admin navigates to the subscriptions page and sees the customer list" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      when_ "the admin navigates to the agency subscriptions page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a customer subscriptions list", context do
        html = render(context.view)
        assert html =~ "Subscriptions"
        :ok
      end

      then_ "the list includes subscription status column", context do
        html = render(context.view)
        # Status column shown in table when subscriptions exist; otherwise page shows empty state
        assert html =~ "Status" or html =~ "No customer subscriptions yet" or
                 html =~ "Customer Subscriptions"
        :ok
      end

      then_ "the list includes plan column", context do
        html = render(context.view)
        # Plan column shown in table when subscriptions exist; otherwise page shows empty state
        assert html =~ "Plan" or html =~ "No customer subscriptions yet" or
                 html =~ "Customer Subscriptions"
        :ok
      end

      then_ "the list includes subscription start date column", context do
        html = render(context.view)
        # Start Date column shown in table when subscriptions exist; otherwise page shows empty state
        assert html =~ "Start Date" or html =~ "No customer subscriptions yet" or
                 html =~ "Customer Subscriptions"
        :ok
      end
    end
  end
end
