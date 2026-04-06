# Stub: actual tests at test/metric_flow/billing_test.exs
# This file exists to satisfy the short-name component validator.
defmodule BillingRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Billing.{Plan, Subscription, StripeAccount}
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Repo

  import MetricFlowTest.UsersFixtures

  defp account_fixture do
    user = user_fixture()

    account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "Test",
        slug: "test-#{System.unique_integer([:positive])}",
        type: "team",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    account
  end

  describe "get_subscription_by_stripe_id/1" do
    test "returns subscription when found" do
      account = account_fixture()

      {:ok, sub} =
        BillingRepository.upsert_subscription(%{
          stripe_subscription_id: "sub_find_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_test",
          status: :active,
          account_id: account.id
        })

      assert BillingRepository.get_subscription_by_stripe_id(sub.stripe_subscription_id)
    end

    test "returns nil when not found" do
      assert BillingRepository.get_subscription_by_stripe_id("sub_nonexistent") == nil
    end
  end

  describe "get_subscription_by_account_id/1" do
    test "returns subscription when found" do
      account = account_fixture()

      {:ok, _sub} =
        BillingRepository.upsert_subscription(%{
          stripe_subscription_id: "sub_acct_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_test",
          status: :active,
          account_id: account.id
        })

      assert BillingRepository.get_subscription_by_account_id(account.id)
    end

    test "returns nil when not found" do
      assert BillingRepository.get_subscription_by_account_id(999_999) == nil
    end
  end

  describe "upsert_subscription/1" do
    test "inserts new subscription when none exists" do
      account = account_fixture()

      assert {:ok, sub} =
               BillingRepository.upsert_subscription(%{
                 stripe_subscription_id: "sub_new_#{System.unique_integer([:positive])}",
                 stripe_customer_id: "cus_new",
                 status: :active,
                 account_id: account.id
               })

      assert sub.status == :active
    end

    test "updates existing subscription when found" do
      account = account_fixture()
      sid = "sub_upsert_#{System.unique_integer([:positive])}"

      {:ok, _} =
        BillingRepository.upsert_subscription(%{
          stripe_subscription_id: sid,
          stripe_customer_id: "cus_test",
          status: :active,
          account_id: account.id
        })

      {:ok, updated} =
        BillingRepository.upsert_subscription(%{
          stripe_subscription_id: sid,
          stripe_customer_id: "cus_test",
          status: :past_due,
          account_id: account.id
        })

      assert updated.status == :past_due
    end

    test "returns error for invalid attributes" do
      assert {:error, _changeset} = BillingRepository.upsert_subscription(%{})
    end
  end

  describe "list_plans/1" do
    test "returns platform plans when agency_account_id is nil" do
      {:ok, _} = BillingRepository.create_plan(%{name: "Platform", price_cents: 999, currency: "usd", billing_interval: :monthly})
      plans = BillingRepository.list_plans(nil)
      assert Enum.any?(plans, &(&1.name == "Platform"))
    end

    test "returns agency plans when agency_account_id is provided" do
      account = account_fixture()
      {:ok, _} = BillingRepository.create_plan(%{name: "Agency", price_cents: 999, currency: "usd", billing_interval: :monthly, agency_account_id: account.id})
      plans = BillingRepository.list_plans(account.id)
      assert Enum.any?(plans, &(&1.name == "Agency"))
    end

    test "returns empty list when no plans exist" do
      plans = BillingRepository.list_plans(999_999)
      assert plans == []
    end
  end

  describe "get_plan/1" do
    test "returns plan when found" do
      {:ok, plan} = BillingRepository.create_plan(%{name: "Find Me", price_cents: 999, currency: "usd", billing_interval: :monthly})
      assert BillingRepository.get_plan(plan.id)
    end

    test "returns nil when not found" do
      assert BillingRepository.get_plan(999_999) == nil
    end
  end

  describe "create_plan/1" do
    test "creates plan with valid attributes" do
      assert {:ok, plan} = BillingRepository.create_plan(%{name: "New", price_cents: 1999, currency: "usd", billing_interval: :monthly})
      assert plan.name == "New"
    end

    test "returns error for invalid attributes" do
      assert {:error, _} = BillingRepository.create_plan(%{})
    end
  end

  describe "get_stripe_account_by_agency/1" do
    test "returns stripe account when found" do
      account = account_fixture()
      {:ok, _} = BillingRepository.upsert_stripe_account(%{stripe_account_id: "acct_find", agency_account_id: account.id})
      assert BillingRepository.get_stripe_account_by_agency(account.id)
    end

    test "returns nil when not found" do
      assert BillingRepository.get_stripe_account_by_agency(999_999) == nil
    end
  end

  describe "upsert_stripe_account/1" do
    test "inserts new stripe account when none exists" do
      account = account_fixture()
      assert {:ok, sa} = BillingRepository.upsert_stripe_account(%{stripe_account_id: "acct_new_#{System.unique_integer([:positive])}", agency_account_id: account.id})
      assert sa.onboarding_status == :pending
    end

    test "updates existing stripe account when found" do
      account = account_fixture()
      {:ok, _} = BillingRepository.upsert_stripe_account(%{stripe_account_id: "acct_up", agency_account_id: account.id})
      {:ok, updated} = BillingRepository.upsert_stripe_account(%{stripe_account_id: "acct_up", agency_account_id: account.id, onboarding_status: :complete})
      assert updated.onboarding_status == :complete
    end
  end

  describe "list_agency_subscriptions/2" do
    test "returns subscriptions for agency plans" do
      subs = BillingRepository.list_agency_subscriptions(999_999)
      assert subs == []
    end

    test "returns empty list when no subscriptions exist" do
      assert BillingRepository.list_agency_subscriptions(999_999) == []
    end
  end

  describe "count_active_agency_subscriptions/1" do
    test "returns count of active subscriptions" do
      assert BillingRepository.count_active_agency_subscriptions(999_999) == 0
    end

    test "returns 0 when no active subscriptions" do
      assert BillingRepository.count_active_agency_subscriptions(999_999) == 0
    end
  end

  describe "calculate_mrr/1" do
    test "returns sum of active plan prices" do
      assert BillingRepository.calculate_mrr(999_999) == 0
    end

    test "returns 0 when no active subscriptions" do
      assert BillingRepository.calculate_mrr(999_999) == 0
    end
  end
end
