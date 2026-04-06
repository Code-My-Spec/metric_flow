defmodule MetricFlow.Billing.SubscriptionTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing.Subscription
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Repo

  import MetricFlowTest.UsersFixtures

  defp account_fixture do
    user = user_fixture()

    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account",
      slug: "test-#{System.unique_integer([:positive])}",
      type: "team",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  @valid_attrs %{
    stripe_subscription_id: "sub_test_123",
    stripe_customer_id: "cus_test_456",
    status: :active
  }

  describe "changeset/2" do
    test "returns valid changeset for valid attributes" do
      account = account_fixture()
      attrs = Map.put(@valid_attrs, :account_id, account.id)
      changeset = Subscription.changeset(%Subscription{}, attrs)
      assert changeset.valid?
    end

    test "returns error changeset for missing required fields" do
      changeset = Subscription.changeset(%Subscription{}, %{})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert "can't be blank" in errors[:stripe_subscription_id]
      assert "can't be blank" in errors[:stripe_customer_id]
      assert "can't be blank" in errors[:account_id]
    end
  end
end
