defmodule MetricFlowSpex.Story48.Criterion4143Spex do
  @moduledoc """
  Story 1101 — Agency Plan Management: Create Custom Subscription Plans
  Criterion 4143 — Another agency's admin cannot see or select this plan
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Another agency's admin cannot see or select this plan", criterion: 467 do
    scenario "a plan is invisible outside its owning account" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect
      given_ :owner_has_agency_plan

      given_ "a second, unaffiliated user is registered and logged in", context do
        email = "otheruser#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Other Account"}
        )
        |> render_submit()

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        logged_in_conn = submit_form(login_form, login_conn)

        {:ok, Map.put(context, :other_conn, recycle(logged_in_conn))}
      end

      when_ "the other admin views their own agency's plan list", context do
        {:ok, other_plans_view, _html} = live(context.other_conn, "/app/agency/plans")
        {:ok, Map.put(context, :other_plans_view, other_plans_view)}
      end

      then_ "the plan does not appear on the other agency's plan list", context do
        refute render(context.other_plans_view) =~ context.agency_plan.name
        {:ok, context}
      end

      then_ "a user with no affiliation to Acme Agency does not see the plan either", context do
        {:ok, checkout_view, _html} = live(context.other_conn, "/app/subscriptions/checkout")
        refute render(checkout_view) =~ context.agency_plan.name
        {:ok, context}
      end
    end
  end
end
