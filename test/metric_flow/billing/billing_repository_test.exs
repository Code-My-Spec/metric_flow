defmodule MetricFlow.Billing.BillingRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing.BillingRepository

  import MetricFlowTest.AiFixtures, only: [user_with_scope: 0]

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_account do
    {user, scope} = user_with_scope()
    account_id = MetricFlow.Accounts.get_personal_account_id(scope)
    {user, account_id, scope}
  end

  defp valid_subscription_attrs(account_id, overrides \\ %{}) do
    Map.merge(
      %{
        stripe_subscription_id: "sub_#{System.unique_integer([:positive])}",
        stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
        status: :active,
        account_id: account_id,
        current_period_start: ~U[2026-04-01 00:00:00Z],
        current_period_end: ~U[2026-05-01 00:00:00Z]
      },
      overrides
    )
  end

  defp insert_subscription!(account_id, overrides \\ %{}) do
    {:ok, sub} = BillingRepository.upsert_subscription(valid_subscription_attrs(account_id, overrides))
    sub
  end

  defp valid_plan_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        name: "Plan #{System.unique_integer([:positive])}",
        price_cents: 2999,
        currency: "usd",
        billing_interval: :monthly
      },
      overrides
    )
  end

  defp insert_plan!(overrides \\ %{}) do
    {:ok, plan} = BillingRepository.create_plan(valid_plan_attrs(overrides))
    plan
  end

  defp valid_stripe_account_attrs(agency_account_id, overrides \\ %{}) do
    Map.merge(
      %{
        stripe_account_id: "acct_#{System.unique_integer([:positive])}",
        agency_account_id: agency_account_id,
        onboarding_status: :pending,
        capabilities: %{}
      },
      overrides
    )
  end

  defp insert_stripe_account!(agency_account_id, overrides \\ %{}) do
    {:ok, sa} = BillingRepository.upsert_stripe_account(valid_stripe_account_attrs(agency_account_id, overrides))
    sa
  end

  # ---------------------------------------------------------------------------
  # get_subscription_by_stripe_id/1
  # ---------------------------------------------------------------------------

  describe "get_subscription_by_stripe_id/1" do
    test "returns the subscription when stripe_subscription_id matches" do
      {_user, account_id, _scope} = create_account()
      sub = insert_subscription!(account_id)

      result = BillingRepository.get_subscription_by_stripe_id(sub.stripe_subscription_id)
      assert result.id == sub.id
    end

    test "returns nil when no subscription matches" do
      assert BillingRepository.get_subscription_by_stripe_id("sub_nonexistent") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # get_subscription_by_account_id/1
  # ---------------------------------------------------------------------------

  describe "get_subscription_by_account_id/1" do
    test "returns the subscription when account_id matches" do
      {_user, account_id, _scope} = create_account()
      sub = insert_subscription!(account_id)

      result = BillingRepository.get_subscription_by_account_id(account_id)
      assert result.id == sub.id
    end

    test "returns nil when no subscription matches" do
      assert BillingRepository.get_subscription_by_account_id(-1) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_subscription/1
  # ---------------------------------------------------------------------------

  describe "upsert_subscription/1" do
    test "creates a new subscription when stripe_subscription_id does not exist" do
      {_user, account_id, _scope} = create_account()
      attrs = valid_subscription_attrs(account_id)

      assert {:ok, sub} = BillingRepository.upsert_subscription(attrs)
      assert sub.stripe_subscription_id == attrs.stripe_subscription_id
      assert sub.account_id == account_id
    end

    test "updates an existing subscription when stripe_subscription_id already exists" do
      {_user, account_id, _scope} = create_account()
      sub = insert_subscription!(account_id)

      assert {:ok, updated} =
               BillingRepository.upsert_subscription(%{
                 stripe_subscription_id: sub.stripe_subscription_id,
                 stripe_customer_id: sub.stripe_customer_id,
                 status: :past_due,
                 account_id: account_id
               })

      assert updated.id == sub.id
      assert updated.status == :past_due
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, %Ecto.Changeset{}} = BillingRepository.upsert_subscription(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # list_plans/1
  # ---------------------------------------------------------------------------

  describe "list_plans/1" do
    test "returns platform plans when agency_account_id is nil" do
      platform_plan = insert_plan!()
      {_user, agency_id, _scope} = create_account()
      _agency_plan = insert_plan!(%{agency_account_id: agency_id})

      plans = BillingRepository.list_plans(nil)
      plan_ids = Enum.map(plans, & &1.id)

      assert platform_plan.id in plan_ids
      refute agency_id in Enum.map(plans, & &1.agency_account_id)
    end

    test "returns agency-specific plans when agency_account_id is provided" do
      _platform_plan = insert_plan!()
      {_user, agency_id, _scope} = create_account()
      agency_plan = insert_plan!(%{agency_account_id: agency_id})

      plans = BillingRepository.list_plans(agency_id)
      plan_ids = Enum.map(plans, & &1.id)

      assert agency_plan.id in plan_ids
    end

    test "excludes inactive plans" do
      insert_plan!(%{active: false})

      plans = BillingRepository.list_plans(nil)
      assert Enum.all?(plans, & &1.active)
    end

    test "returns plans ordered by price ascending" do
      insert_plan!(%{price_cents: 5999})
      insert_plan!(%{price_cents: 999})
      insert_plan!(%{price_cents: 2999})

      plans = BillingRepository.list_plans(nil)
      prices = Enum.map(plans, & &1.price_cents)

      assert prices == Enum.sort(prices)
    end
  end

  # ---------------------------------------------------------------------------
  # get_plan/1
  # ---------------------------------------------------------------------------

  describe "get_plan/1" do
    test "returns the plan when ID matches" do
      plan = insert_plan!()
      assert BillingRepository.get_plan(plan.id).id == plan.id
    end

    test "returns nil when no plan matches" do
      assert BillingRepository.get_plan(-1) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # create_plan/1
  # ---------------------------------------------------------------------------

  describe "create_plan/1" do
    test "creates a plan with valid attributes" do
      attrs = valid_plan_attrs()
      assert {:ok, plan} = BillingRepository.create_plan(attrs)
      assert plan.name == attrs.name
      assert plan.price_cents == attrs.price_cents
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, %Ecto.Changeset{}} = BillingRepository.create_plan(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # get_stripe_account_by_agency/1
  # ---------------------------------------------------------------------------

  describe "get_stripe_account_by_agency/1" do
    test "returns the stripe account when agency_account_id matches" do
      {_user, agency_id, _scope} = create_account()
      sa = insert_stripe_account!(agency_id)

      result = BillingRepository.get_stripe_account_by_agency(agency_id)
      assert result.id == sa.id
    end

    test "returns nil when no stripe account matches" do
      assert BillingRepository.get_stripe_account_by_agency(-1) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_stripe_account/1
  # ---------------------------------------------------------------------------

  describe "upsert_stripe_account/1" do
    test "creates a new stripe account when agency_account_id does not exist" do
      {_user, agency_id, _scope} = create_account()
      attrs = valid_stripe_account_attrs(agency_id)

      assert {:ok, sa} = BillingRepository.upsert_stripe_account(attrs)
      assert sa.stripe_account_id == attrs.stripe_account_id
      assert sa.agency_account_id == agency_id
    end

    test "updates an existing stripe account when agency_account_id already exists" do
      {_user, agency_id, _scope} = create_account()
      sa = insert_stripe_account!(agency_id)

      assert {:ok, updated} =
               BillingRepository.upsert_stripe_account(%{
                 stripe_account_id: sa.stripe_account_id,
                 agency_account_id: agency_id,
                 onboarding_status: :complete
               })

      assert updated.id == sa.id
      assert updated.onboarding_status == :complete
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, %Ecto.Changeset{}} = BillingRepository.upsert_stripe_account(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # list_agency_subscriptions/2
  # ---------------------------------------------------------------------------

  describe "list_agency_subscriptions/2" do
    test "returns subscriptions for plans owned by the agency" do
      {_user, agency_id, _scope} = create_account()
      agency_plan = insert_plan!(%{agency_account_id: agency_id})

      {_user2, customer_id, _scope2} = create_account()
      _sub = insert_subscription!(customer_id, %{plan_id: agency_plan.id})

      results = BillingRepository.list_agency_subscriptions(agency_id)
      assert length(results) == 1
      assert hd(results).plan_id == agency_plan.id
    end

    test "returns empty list when agency has no subscriptions" do
      {_user, agency_id, _scope} = create_account()
      _agency_plan = insert_plan!(%{agency_account_id: agency_id})

      assert BillingRepository.list_agency_subscriptions(agency_id) == []
    end

    test "filters by search term when provided" do
      {_user, agency_id, _scope} = create_account()
      agency_plan = insert_plan!(%{agency_account_id: agency_id})

      {_user2, customer_id, _scope2} = create_account()
      sub = insert_subscription!(customer_id, %{plan_id: agency_plan.id, stripe_customer_id: "cus_searchable_123"})

      results = BillingRepository.list_agency_subscriptions(agency_id, search: "searchable")
      assert length(results) == 1
      assert hd(results).id == sub.id

      empty = BillingRepository.list_agency_subscriptions(agency_id, search: "nonexistent")
      assert empty == []
    end
  end

  # ---------------------------------------------------------------------------
  # count_active_agency_subscriptions/1
  # ---------------------------------------------------------------------------

  describe "count_active_agency_subscriptions/1" do
    test "returns count of active subscriptions for the agency" do
      {_user, agency_id, _scope} = create_account()
      agency_plan = insert_plan!(%{agency_account_id: agency_id})

      {_user2, customer_id, _scope2} = create_account()
      _sub = insert_subscription!(customer_id, %{plan_id: agency_plan.id, status: :active})

      assert BillingRepository.count_active_agency_subscriptions(agency_id) == 1
    end

    test "returns 0 when no active subscriptions exist" do
      {_user, agency_id, _scope} = create_account()
      _agency_plan = insert_plan!(%{agency_account_id: agency_id})

      assert BillingRepository.count_active_agency_subscriptions(agency_id) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # calculate_mrr/1
  # ---------------------------------------------------------------------------

  describe "calculate_mrr/1" do
    test "returns sum of price_cents from active subscriptions" do
      {_user, agency_id, _scope} = create_account()
      agency_plan = insert_plan!(%{agency_account_id: agency_id, price_cents: 4999})

      {_user2, customer_id, _scope2} = create_account()
      _sub = insert_subscription!(customer_id, %{plan_id: agency_plan.id, status: :active})

      assert BillingRepository.calculate_mrr(agency_id) == 4999
    end

    test "returns 0 when no active subscriptions exist" do
      {_user, agency_id, _scope} = create_account()
      _agency_plan = insert_plan!(%{agency_account_id: agency_id})

      assert BillingRepository.calculate_mrr(agency_id) == 0
    end
  end
end
