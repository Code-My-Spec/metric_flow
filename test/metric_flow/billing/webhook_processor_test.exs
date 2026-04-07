defmodule MetricFlow.Billing.WebhookProcessorTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing.{BillingRepository, WebhookProcessor}

  import MetricFlowTest.AiFixtures, only: [user_with_scope: 0]

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_account do
    {user, scope} = user_with_scope()
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)
    {user, account_id, scope}
  end

  defp create_subscription(account_id, attrs \\ %{}) do
    base = %{
      stripe_subscription_id: "sub_#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      status: :active,
      account_id: account_id,
      current_period_start: ~U[2026-04-01 00:00:00Z],
      current_period_end: ~U[2026-05-01 00:00:00Z]
    }

    {:ok, subscription} = BillingRepository.upsert_subscription(Map.merge(base, attrs))
    subscription
  end

  defp create_stripe_account(agency_account_id, attrs \\ %{}) do
    base = %{
      stripe_account_id: "acct_#{System.unique_integer([:positive])}",
      agency_account_id: agency_account_id,
      onboarding_status: :pending,
      capabilities: %{}
    }

    {:ok, stripe_account} = BillingRepository.upsert_stripe_account(Map.merge(base, attrs))
    stripe_account
  end

  defp build_event(type, object) do
    %{
      "id" => "evt_#{System.unique_integer([:positive])}",
      "type" => type,
      "data" => %{"object" => object}
    }
  end

  # ---------------------------------------------------------------------------
  # process_event/1
  # ---------------------------------------------------------------------------

  describe "process_event/1" do
    test "creates a local subscription from a subscription.created event" do
      {_user, account_id, _scope} = create_account()

      stripe_sub_id = "sub_new_#{System.unique_integer([:positive])}"

      event =
        build_event("customer.subscription.created", %{
          "id" => stripe_sub_id,
          "customer" => "cus_new_123",
          "status" => "active",
          "current_period_start" => 1_711_929_600,
          "current_period_end" => 1_714_521_600,
          "metadata" => %{"account_id" => to_string(account_id)}
        })

      assert :ok = WebhookProcessor.process_event(event)

      subscription = BillingRepository.get_subscription_by_stripe_id(stripe_sub_id)
      assert subscription != nil
      assert subscription.stripe_subscription_id == stripe_sub_id
      assert subscription.stripe_customer_id == "cus_new_123"
      assert subscription.status == :active
      assert subscription.account_id == account_id
    end

    test "updates subscription status and period from a subscription.updated event" do
      {_user, account_id, _scope} = create_account()
      subscription = create_subscription(account_id)

      event =
        build_event("customer.subscription.updated", %{
          "id" => subscription.stripe_subscription_id,
          "customer" => subscription.stripe_customer_id,
          "status" => "past_due",
          "current_period_start" => 1_714_521_600,
          "current_period_end" => 1_717_200_000,
          "metadata" => %{"account_id" => to_string(account_id)}
        })

      assert :ok = WebhookProcessor.process_event(event)

      updated = BillingRepository.get_subscription_by_stripe_id(subscription.stripe_subscription_id)
      assert updated.status == :past_due
    end

    test "marks subscription as cancelled from a subscription.deleted event" do
      {_user, account_id, _scope} = create_account()
      subscription = create_subscription(account_id)

      event =
        build_event("customer.subscription.deleted", %{
          "id" => subscription.stripe_subscription_id,
          "customer" => subscription.stripe_customer_id,
          "status" => "canceled",
          "canceled_at" => 1_714_521_600,
          "metadata" => %{"account_id" => to_string(account_id)}
        })

      assert :ok = WebhookProcessor.process_event(event)

      updated = BillingRepository.get_subscription_by_stripe_id(subscription.stripe_subscription_id)
      assert updated.status == :cancelled
      assert updated.cancelled_at != nil
    end

    test "sets subscription to past_due from an invoice.payment_failed event" do
      {_user, account_id, _scope} = create_account()
      subscription = create_subscription(account_id)

      event =
        build_event("invoice.payment_failed", %{
          "id" => "in_#{System.unique_integer([:positive])}",
          "subscription" => subscription.stripe_subscription_id,
          "customer" => subscription.stripe_customer_id
        })

      assert :ok = WebhookProcessor.process_event(event)

      updated = BillingRepository.get_subscription_by_stripe_id(subscription.stripe_subscription_id)
      assert updated.status == :past_due
    end

    test "updates Stripe account onboarding status from an account.updated event" do
      {_user, account_id, _scope} = create_account()
      stripe_account = create_stripe_account(account_id)

      event =
        build_event("account.updated", %{
          "id" => stripe_account.stripe_account_id,
          "charges_enabled" => true,
          "payouts_enabled" => true,
          "details_submitted" => true
        })

      assert :ok = WebhookProcessor.process_event(event)

      updated = BillingRepository.get_stripe_account_by_agency(account_id)
      assert updated.onboarding_status == :complete
    end

    test "returns :ok for unrecognized event types" do
      event = build_event("some.unknown.event", %{"id" => "obj_123"})

      assert :ok = WebhookProcessor.process_event(event)
    end
  end
end
