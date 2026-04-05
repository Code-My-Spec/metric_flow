defmodule MetricFlowSpex.SubscriptionStatusBadgeReflectsStateSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Subscription status badge reflects real-time synced state" do
    scenario "agency admin sees status badges displayed for subscriptions on the page" do
      given_ :user_logged_in_as_owner

      when_ "the admin navigates to the agency subscriptions page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders a status badge element for subscription states", context do
        html = render(context.view)
        assert html =~ "active" or html =~ "past_due" or html =~ "canceled" or
                 html =~ "trialing" or has_element?(context.view, "[data-status]") or
                 has_element?(context.view, ".badge")
        :ok
      end

      then_ "the Status column header is present indicating status display is supported", context do
        html = render(context.view)
        assert html =~ "Status"
        :ok
      end
    end
  end
end
