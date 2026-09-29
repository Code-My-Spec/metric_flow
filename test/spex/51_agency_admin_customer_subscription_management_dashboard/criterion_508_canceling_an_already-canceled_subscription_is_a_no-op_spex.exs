defmodule MetricFlowSpex.CancelingAnAlreadyCanceledSubscriptionIsANoOpSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Canceling an already-canceled subscription is a no-op", criterion: 508 do
    scenario "Jordan's subscription is already canceled" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_stripe_connect

      given_ "Jordan's subscription is already canceled", context do
        subscription =
          MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)

        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")

        view
        |> element("button[phx-value-id='#{subscription.id}']")
        |> render_click()

        {:ok, Map.put(context, :jordan_subscription_id, subscription.id)}
      end

      when_ "Alex attempts to cancel it again from the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no duplicate cancellation request is sent to Stripe and Alex sees the subscription is already canceled",
            context do
        html = render(context.view)

        refute has_element?(context.view, "button[phx-value-id='#{context.jordan_subscription_id}']"),
               "Expected no cancel action to remain available once the subscription is already cancelled"

        assert html =~ "Cancelled",
               "Expected the dashboard to show the subscription as already cancelled. Got: #{html}"

        {:ok, context}
      end
    end
  end
end
