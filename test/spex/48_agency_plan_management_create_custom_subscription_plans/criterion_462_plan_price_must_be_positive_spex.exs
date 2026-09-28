defmodule MetricFlowSpex.Story48.Criterion4138Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4138 — Plan price must be positive
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Plan price must be positive", criterion: 462 do
    scenario "submitting a plan with a zero price is rejected" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "Alex is creating a new plan named \"Pro\"", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex submits a monthly price of $0", context do
        context.view
        |> form("#plan-form",
          plan: %{name: "Pro", price_cents: "0", billing_interval: "monthly"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the plan is rejected with a validation error requiring a positive price", context do
        html = render(context.view)
        assert html =~ "must be greater than 0"
        {:ok, context}
      end
    end
  end
end
