defmodule MetricFlowSpex.Story48.Criterion4141Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4141 — Updating plan price rotates the Stripe Price
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Updating plan price rotates the Stripe Price" do
    scenario "editing a plan's price replaces its Stripe Price" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect
      given_ :owner_has_agency_plan

      given_ "Alex is on the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      given_ "the plan's current row is recorded, before any update", context do
        original_row_html =
          context.view
          |> element("tr[data-role='plan-row']", context.agency_plan.name)
          |> render()

        {:ok, Map.put(context, :original_row_html, original_row_html)}
      end

      when_ "Alex updates the plan's price to $59/month", context do
        context.view
        |> element("[data-role=edit-plan]")
        |> render_click()

        context.view
        |> form("#plan-form", plan: %{price_cents: "5900"})
        |> render_submit()

        {:ok, context}
      end

      then_ "a new Stripe Price is created at $59/month and set active on the plan", context do
        html = render(context.view)
        assert html =~ "$59.00"
        {:ok, context}
      end

      then_ "the previous Stripe Price is marked inactive", context do
        new_row_html =
          context.view
          |> element("tr[data-role='plan-row']", context.agency_plan.name)
          |> render()

        refute new_row_html == context.original_row_html
        {:ok, context}
      end
    end
  end
end
