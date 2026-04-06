defmodule MetricFlow.Billing.PlanTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.Billing.Plan

  @valid_attrs %{
    name: "Pro Plan",
    price_cents: 2999,
    currency: "usd",
    billing_interval: :monthly
  }

  describe "changeset/2" do
    test "returns valid changeset for valid attributes" do
      changeset = Plan.changeset(%Plan{}, @valid_attrs)
      assert changeset.valid?
    end

    test "returns error changeset for missing required fields" do
      changeset = Plan.changeset(%Plan{}, %{})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert "can't be blank" in errors[:name]
      assert "can't be blank" in errors[:price_cents]
    end

    test "validates price_cents is greater than 0" do
      attrs = Map.put(@valid_attrs, :price_cents, 0)
      changeset = Plan.changeset(%Plan{}, attrs)
      refute changeset.valid?
      assert %{price_cents: ["must be greater than 0"]} = errors_on(changeset)

      attrs_negative = Map.put(@valid_attrs, :price_cents, -100)
      changeset_negative = Plan.changeset(%Plan{}, attrs_negative)
      refute changeset_negative.valid?
      assert %{price_cents: ["must be greater than 0"]} = errors_on(changeset_negative)
    end

    test "validates currency is one of usd, eur, gbp" do
      attrs = Map.put(@valid_attrs, :currency, "jpy")
      changeset = Plan.changeset(%Plan{}, attrs)
      refute changeset.valid?
      assert %{currency: ["is invalid"]} = errors_on(changeset)

      for valid_currency <- ["usd", "eur", "gbp"] do
        valid_changeset = Plan.changeset(%Plan{}, Map.put(@valid_attrs, :currency, valid_currency))
        assert valid_changeset.valid?, "Expected #{valid_currency} to be valid"
      end
    end
  end
end
