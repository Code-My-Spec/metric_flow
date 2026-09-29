defmodule MetricFlowSpex.AgencyAdminCancelsACustomersSubscriptionAtPeriodEndSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency admin cancels a customer's subscription at period end", criterion: 507 do
    scenario "Jordan has an active subscription under Acme Agency" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_stripe_connect

      given_ "Jordan has an active subscription under Acme Agency", context do
        subscription =
          MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)

        {:ok, Map.put(context, :jordan_subscription_id, subscription.id)}
      end

      given_ "Alex is on the subscription management dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex cancels Jordan's subscription from the dashboard", context do
        context.view
        |> element("button[phx-value-id='#{context.jordan_subscription_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "Stripe schedules the cancellation for the end of the current billing period on Acme Agency's connected account",
            context do
        html = render(context.view)

        assert html =~ "Cancelled",
               "Expected Jordan's subscription to show as cancelled once scheduled for period-end cancellation. Got: #{html}"

        {:ok, context}
      end
    end
  end
end
