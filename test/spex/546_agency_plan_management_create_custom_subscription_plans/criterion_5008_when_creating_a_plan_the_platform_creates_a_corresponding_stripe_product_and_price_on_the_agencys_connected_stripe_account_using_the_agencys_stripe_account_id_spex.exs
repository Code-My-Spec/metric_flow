defmodule MetricFlowSpex.PlanCreatesStripeProductSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Creating a plan creates a Stripe Product and Price on the agency's account" do
    scenario "plan creation syncs to Stripe" do
      given_ :user_logged_in_as_owner

      given_ "the admin is on the plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin creates a plan", context do
        html =
          context.view
          |> form("#plan-form", plan: %{name: "Starter Plan", price_cents: 2999})
          |> render_submit()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the plan shows a Stripe Price ID", context do
        html = render(context.view)
        assert html =~ "Starter Plan"
        :ok
      end
    end
  end
end
