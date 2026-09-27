defmodule MetricFlowSpex.CancellingAnAlreadyScheduledCancellationIsANoOpSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  spex "Cancelling an already-scheduled cancellation is a no-op" do
    scenario "attempting to cancel an already-cancelled subscription does not error" do
      given_(:user_logged_in_as_owner)

      given_ "the user's subscription is already scheduled to cancel", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: "sub_noop_#{System.unique_integer([:positive])}",
            stripe_customer_id: "cus_noop_#{System.unique_integer([:positive])}",
            status: :cancelled,
            account_id: account_id,
            cancelled_at: DateTime.utc_now(),
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 10, :day)
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they attempt to cancel again", context do
        html = render_click(context.view, "cancel_subscription")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the system indicates cancellation is already scheduled rather than erroring", context do
        assert context.html =~ "Cancelled"
        refute context.html =~ "Failed to cancel"
        {:ok, context}
      end
    end
  end
end
