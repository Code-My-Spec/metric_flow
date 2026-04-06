defmodule MetricFlow.Billing.WebhookProcessorTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing
  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Repo

  import MetricFlowTest.UsersFixtures

  defp account_fixture do
    user = user_fixture()

    %Account{}
    |> Account.creation_changeset(%{
      name: "Webhook Test Account",
      slug: "webhook-test-#{System.unique_integer([:positive])}",
      type: "team",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  describe "process_webhook_event/1" do
    test "processes subscription.created event" do
      account = account_fixture()

      sub_id = "sub_created_#{System.unique_integer([:positive])}"
      customer_id = "cus_test_#{System.unique_integer([:positive])}"

      # Pre-create a subscription so the upsert path finds it and updates it,
      # since creating from a webhook alone lacks account_id.
      {:ok, _} =
        BillingRepository.upsert_subscription(%{
          stripe_subscription_id: sub_id,
          stripe_customer_id: customer_id,
          status: :incomplete,
          account_id: account.id
        })

      event = %{
        "type" => "customer.subscription.created",
        "data" => %{
          "object" => %{
            "id" => sub_id,
            "customer" => customer_id,
            "status" => "active",
            "current_period_start" => 1_700_000_000,
            "current_period_end" => 1_702_592_000
          }
        }
      }

      assert :ok = Billing.process_webhook_event(event)

      subscription = BillingRepository.get_subscription_by_stripe_id(sub_id)
      assert subscription
      assert subscription.status == :active
      assert subscription.stripe_customer_id == customer_id
    end

    test "processes invoice.payment_failed event" do
      account = account_fixture()
      sub_id = "sub_fail_#{System.unique_integer([:positive])}"

      {:ok, _sub} =
        BillingRepository.upsert_subscription(%{
          stripe_subscription_id: sub_id,
          stripe_customer_id: "cus_fail_test",
          status: :active,
          account_id: account.id
        })

      event = %{
        "type" => "invoice.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "in_test_123",
            "subscription" => sub_id
          }
        }
      }

      assert :ok = Billing.process_webhook_event(event)

      updated_sub = BillingRepository.get_subscription_by_stripe_id(sub_id)
      assert updated_sub.status == :past_due
    end

    test "returns ignored for unrecognized event types" do
      event = %{
        "type" => "some.unknown.event",
        "data" => %{"object" => %{}}
      }

      assert {:ok, :ignored} = Billing.process_webhook_event(event)
    end
  end
end
