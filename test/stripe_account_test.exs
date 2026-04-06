defmodule MetricFlow.Billing.StripeAccountTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing.StripeAccount

  describe "changeset/2" do
    test "returns valid changeset for valid attributes" do
      attrs = %{
        stripe_account_id: "acct_test_123",
        agency_account_id: 1
      }

      changeset = StripeAccount.changeset(%StripeAccount{}, attrs)
      assert changeset.valid?
    end

    test "returns error changeset for missing required fields" do
      changeset = StripeAccount.changeset(%StripeAccount{}, %{})
      refute changeset.valid?

      assert %{
               stripe_account_id: ["can't be blank"],
               agency_account_id: ["can't be blank"]
             } = errors_on(changeset)
    end
  end
end
