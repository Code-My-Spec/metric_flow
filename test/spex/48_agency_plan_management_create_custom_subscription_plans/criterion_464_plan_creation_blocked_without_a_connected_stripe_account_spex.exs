defmodule MetricFlowSpex.Story48.Criterion4140Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4140 — Plan creation blocked without a connected Stripe account
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Plan creation blocked without a connected Stripe account", criterion: 464 do
    scenario "attempting to create a plan without Stripe Connect is rejected" do
      given_ :user_logged_in_as_owner

      given_ "Acme Agency has no connected Stripe account, and Alex is on the plans page",
             context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex attempts to create a plan", context do
        context.view
        |> form("#plan-form",
          plan: %{name: "Pro", price_cents: "4900", billing_interval: "monthly"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the plan is rejected and Alex is told to connect a Stripe account first", context do
        html = render(context.view)
        assert html =~ "Connect your Stripe account before creating plans."
        refute html =~ "Pro"
        {:ok, context}
      end
    end
  end
end
