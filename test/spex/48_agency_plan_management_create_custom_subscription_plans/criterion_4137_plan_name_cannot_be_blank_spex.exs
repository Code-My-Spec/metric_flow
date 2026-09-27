defmodule MetricFlowSpex.Story48.Criterion4137Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4137 — Plan name cannot be blank
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Plan name cannot be blank" do
    scenario "submitting a plan with no name is rejected" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "Alex is creating a new plan", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex submits the plan with no name", context do
        context.view
        |> form("#plan-form",
          plan: %{name: "", price_cents: "1999", billing_interval: "monthly"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the plan is rejected with a validation error requiring a name", context do
        html = render(context.view)
        assert html =~ "can&#39;t be blank"
        {:ok, context}
      end
    end
  end
end
