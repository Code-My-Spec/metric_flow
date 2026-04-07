defmodule MetricFlowSpex.AgencyAdminsCanDefinePlansSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admins can define subscription plans with name and monthly price" do
    scenario "agency admin creates a new plan via the plans page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "the admin navigates to the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin fills in plan details and submits", context do
        html =
          context.view
          |> form("#plan-form", plan: %{name: "Pro Plan", price_cents: 4999})
          |> render_submit()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the new plan appears in the plans list", context do
        html = render(context.view)
        assert html =~ "Pro Plan"
        :ok
      end
    end
  end
end
