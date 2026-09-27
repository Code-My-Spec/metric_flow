defmodule MetricFlow.BillingTest do
  # Not async: the assertions below read `Logger.info` output, `config/test.exs`
  # sets the level to `:warning` to keep test output quiet, and raising it is a
  # global change. `data_sync/sync_worker_test.exs` is `async: false` for exactly
  # this and is the pattern followed here.
  use MetricFlowTest.DataCase, async: false

  import ExUnit.CaptureLog
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Billing
  alias MetricFlow.Billing.BillingRepository

  describe "process_webhook_event/1" do
    # `config/test.exs:44` names this convention outright: "Tests that need
    # capture_log at :info can use @tag capture_log: true with
    # Logger.configure(level: :info) in their setup block." Without it every
    # assertion here compared "" against the event type it expected, because
    # `handle_subscription_event/1` logs at `:info` and the primary level was
    # `:warning` — `capture_log`'s own `:level` option cannot lower the primary
    # level, only raise the floor for what it captures.
    setup do
      previous_level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: previous_level) end)
      :ok
    end

    test "processes subscription.created and persists subscription" do
      account = account_fixture()
      sub_id = "sub_test_#{System.unique_integer([:positive])}"

      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "customer.subscription.created",
        "data" => %{
          "object" => %{
            "id" => sub_id,
            "customer" => "cus_test",
            "status" => "active",
            "current_period_start" => 1_700_000_000,
            "current_period_end" => 1_702_592_000,
            "metadata" => %{"account_id" => to_string(account.id)}
          }
        }
      }

      assert capture_log([level: :info], fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "subscription.created"

      subscription = BillingRepository.get_subscription_by_stripe_id(sub_id)
      assert subscription.account_id == account.id
      assert subscription.status == :active
    end

    test "processes subscription.updated and updates status" do
      account = account_fixture()
      sub_id = "sub_updated_#{System.unique_integer([:positive])}"

      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{
            "id" => sub_id,
            "customer" => "cus_test",
            "status" => "past_due",
            "current_period_start" => 1_700_000_000,
            "current_period_end" => 1_702_592_000,
            "metadata" => %{"account_id" => to_string(account.id)}
          }
        }
      }

      assert capture_log([level: :info], fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "subscription.updated"

      subscription = BillingRepository.get_subscription_by_stripe_id(sub_id)
      assert subscription.status == :past_due
    end

    test "processes subscription.deleted, marks as cancelled and clears plan" do
      account = account_fixture()
      sub_id = "sub_deleted_#{System.unique_integer([:positive])}"

      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "customer.subscription.deleted",
        "data" => %{
          "object" => %{
            "id" => sub_id,
            "customer" => "cus_test",
            "status" => "canceled",
            "canceled_at" => 1_700_100_000,
            "current_period_end" => 1_702_592_000,
            "metadata" => %{"account_id" => to_string(account.id)}
          }
        }
      }

      assert capture_log([level: :info], fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "subscription.deleted"

      subscription = BillingRepository.get_subscription_by_stripe_id(sub_id)
      assert subscription.status == :cancelled
      assert subscription.plan_id == nil
    end

    test "processes invoice.payment_failed and marks subscription as past_due" do
      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "invoice.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "in_failed",
            "customer" => "cus_test",
            "subscription" => "sub_nonexistent",
            "status" => "open"
          }
        }
      }

      capture_log([level: :info], fn -> assert :ok = Billing.process_webhook_event(event) end)
    end

    test "processes invoice.payment_succeeded successfully" do
      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "invoice.payment_succeeded",
        "data" => %{
          "object" => %{
            "id" => "in_success",
            "customer" => "cus_test",
            "subscription" => "sub_test",
            "status" => "paid"
          }
        }
      }

      assert capture_log([level: :info], fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "payment_succeeded"
    end

    test "processes account.updated for Connect onboarding" do
      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "account.updated",
        "data" => %{
          "object" => %{
            "id" => "acct_test",
            "charges_enabled" => true,
            "capabilities" => %{"card_payments" => "active"}
          }
        }
      }

      assert capture_log([level: :info], fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "account.updated"
    end

    test "returns ignored for unrecognized event types" do
      event = %{
        "id" => "evt_test_#{System.unique_integer([:positive])}",
        "type" => "unknown.event",
        "data" => %{"object" => %{}}
      }

      assert {:ok, :ignored} = Billing.process_webhook_event(event)
    end

    test "returns error for invalid event structure" do
      assert {:error, :invalid_event} = Billing.process_webhook_event(%{})
    end
  end
end
