defmodule MetricFlowSpex.Story48.Criterion4136Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4136 — Agency admin creates a new plan
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency admin creates a new plan" do
    scenario "admin creates a plan with a name and monthly price" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "Alex is an agency admin for Acme Agency, on the plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex creates a plan named \"Pro\" with a monthly price of $49", context do
        context.view
        |> form("#plan-form",
          plan: %{name: "Pro", price_cents: "4900", billing_interval: "monthly"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the plan \"Pro\" exists under Acme Agency with a monthly price of $49", context do
        html = render(context.view)
        assert html =~ "Pro"
        assert html =~ "$49.00"
        {:ok, context}
      end
    end
  end
end
