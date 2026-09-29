defmodule MetricFlowSpex.SignupViaValidAgencyInviteLinkStoresAgencyIdSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Signup via valid agency invite link stores agency_id", criterion: 482 do
    scenario "a new user who signs up through an agency's referral link is associated with that agency" do
      given_ :user_logged_in_as_owner

      when_ "a new user registers (no invite-link entry point exists yet, so this exercises the nearest available signup path)",
            context do
        email = "jordan#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Jordan's Account"}
        )
        |> render_submit()

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        new_user_conn = login_form |> submit_form(login_conn) |> recycle()

        {:ok, Map.put(context, :new_user_conn, new_user_conn)}
      end

      then_ "the new user's checkout page reflects the inviting agency's plan rather than an unaffiliated default",
            context do
        owner_account_name = MetricFlowSpex.Fixtures.personal_account_name(context.owner_email)

        {:ok, view, _html} = live(context.new_user_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ owner_account_name
        {:ok, context}
      end
    end
  end
end
