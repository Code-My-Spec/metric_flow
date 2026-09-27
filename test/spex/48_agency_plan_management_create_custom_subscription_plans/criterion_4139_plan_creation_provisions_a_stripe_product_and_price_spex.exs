defmodule MetricFlowSpex.Story48.Criterion4139Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4139 — Plan creation provisions a Stripe Product and Price
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Plan creation provisions a Stripe Product and Price" do
    scenario "creating a plan stores the resulting Stripe Price ID" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "Acme Agency has a connected Stripe account, and Alex is on the plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex creates the plan \"Pro\" at $49/month", context do
        context.view
        |> form("#plan-form",
          plan: %{name: "Pro", price_cents: "4900", billing_interval: "monthly"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "a Stripe Product and Price are created on Acme Agency's connected Stripe account",
            context do
        html = render(context.view)
        assert html =~ "Pro"
        {:ok, context}
      end

      then_ "the plan stores the resulting Stripe Product ID and Price ID", context do
        row_html =
          context.view
          |> element("tr[data-role='plan-row']", "Pro")
          |> render()

        refute row_html =~ "—"
        {:ok, context}
      end
    end
  end
end
