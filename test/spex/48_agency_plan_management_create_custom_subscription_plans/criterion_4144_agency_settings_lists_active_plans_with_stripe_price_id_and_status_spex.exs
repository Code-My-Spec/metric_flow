defmodule MetricFlowSpex.Story48.Criterion4144Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4144 — Agency settings lists active plans with Stripe Price ID and status
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency settings lists active plans with Stripe Price ID and status" do
    scenario "the plans page shows name, Stripe Price ID column, and status for each active plan" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "Alex is on the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      given_ ~s(Acme Agency has the active plans "Pro" and "Basic"), context do
        context.view
        |> form("#plan-form",
          plan: %{name: "Pro", price_cents: "4900", billing_interval: "monthly"}
        )
        |> render_submit()

        context.view
        |> form("#plan-form",
          plan: %{name: "Basic", price_cents: "1900", billing_interval: "monthly"}
        )
        |> render_submit()

        {:ok, context}
      end

      when_ "Alex views the agency settings plans page", context do
        {:ok, view, html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "Alex sees each plan's name, price, Stripe Price ID column, and status", context do
        assert context.html =~ "Pro"
        assert context.html =~ "Basic"
        assert context.html =~ "$49.00"
        assert context.html =~ "$19.00"
        assert context.html =~ "Stripe Price ID"
        assert context.html =~ "Active"
        {:ok, context}
      end
    end
  end
end
