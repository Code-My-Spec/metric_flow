defmodule MetricFlowSpex.Story48.Criterion4142Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4142 — Deactivating a plan stops new signups but keeps existing subscribers
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Deactivating a plan stops new signups but keeps existing subscribers", criterion: 466 do
    scenario "deactivating a plan removes it from new-signup selection but keeps its record" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect
      given_ :owner_has_agency_plan

      given_ "Alex is on the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex deactivates the plan", context do
        context.view
        |> element("[data-role=deactivate-plan]")
        |> render_click()

        {:ok, context}
      end

      then_ "the plan can no longer be selected for new subscriptions", context do
        {:ok, checkout_view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        refute render(checkout_view) =~ context.agency_plan.name
        {:ok, context}
      end

      then_ "the plan remains on record rather than being removed, so existing subscribers stay on it",
            context do
        html = render(context.view)
        assert html =~ context.agency_plan.name
        assert html =~ "Inactive"
        {:ok, context}
      end
    end
  end
end
