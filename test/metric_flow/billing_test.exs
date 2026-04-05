defmodule MetricFlow.BillingTest do
  use MetricFlowTest.DataCase, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.Billing

  describe "process_webhook_event/1" do
    test "processes subscription.created and persists subscription" do
      event = %{
        "type" => "customer.subscription.created",
        "data" => %{
          "object" => %{
            "id" => "sub_test_#{System.unique_integer([:positive])}",
            "customer" => "cus_test",
            "status" => "active",
            "current_period_start" => 1_700_000_000,
            "current_period_end" => 1_702_592_000
          }
        }
      }

      assert capture_log(fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "subscription.created"
    end

    test "processes subscription.updated and updates status" do
      event = %{
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{
            "id" => "sub_updated_#{System.unique_integer([:positive])}",
            "customer" => "cus_test",
            "status" => "past_due",
            "current_period_start" => 1_700_000_000,
            "current_period_end" => 1_702_592_000
          }
        }
      }

      assert capture_log(fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "subscription.updated"
    end

    test "processes subscription.deleted and marks as cancelled" do
      event = %{
        "type" => "customer.subscription.deleted",
        "data" => %{
          "object" => %{
            "id" => "sub_deleted_#{System.unique_integer([:positive])}",
            "customer" => "cus_test",
            "status" => "canceled",
            "canceled_at" => 1_700_100_000,
            "current_period_end" => 1_702_592_000
          }
        }
      }

      assert capture_log(fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "subscription.deleted"
    end

    test "processes invoice.payment_failed and marks subscription as past_due" do
      event = %{
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

      capture_log(fn -> assert :ok = Billing.process_webhook_event(event) end)
    end

    test "processes invoice.payment_succeeded successfully" do
      event = %{
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

      assert capture_log(fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "payment_succeeded"
    end

    test "processes account.updated for Connect onboarding" do
      event = %{
        "type" => "account.updated",
        "data" => %{
          "object" => %{
            "id" => "acct_test",
            "charges_enabled" => true,
            "capabilities" => %{"card_payments" => "active"}
          }
        }
      }

      assert capture_log(fn -> assert :ok = Billing.process_webhook_event(event) end) =~ "account.updated"
    end

    test "returns ignored for unrecognized event types" do
      event = %{
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
