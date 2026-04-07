defmodule MetricFlowSpex.AgencyAdminsSeeSubscriberSummarySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admins can see total active subscribers and MRR in a summary view" do
    scenario "agency admin views the subscriptions page and sees summary metrics" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      when_ "the admin navigates to the agency subscriptions page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a summary section with active subscriber count", context do
        html = render(context.view)
        assert html =~ "Active Subscribers"
        :ok
      end

      then_ "the page shows monthly recurring revenue in the summary", context do
        html = render(context.view)
        assert html =~ "MRR"
        :ok
      end
    end
  end
end
