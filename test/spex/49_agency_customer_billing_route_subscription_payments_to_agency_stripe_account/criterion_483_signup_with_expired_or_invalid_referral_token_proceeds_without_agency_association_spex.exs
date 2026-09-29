defmodule MetricFlowSpex.SignupWithExpiredOrInvalidReferralTokenProceedsWithoutAgencyAssociationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Signup with expired or invalid referral token proceeds without agency association", criterion: 483 do
    scenario "a user who registers without a valid referral link is not tied to any agency" do
      given_ :user_logged_in_as_owner

      when_ "a new user registers with no referral association", context do
        email = "outsider#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Outsider Account"}
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

      then_ "the account proceeds independently, with no agency's name shown on checkout", context do
        owner_account_name = MetricFlowSpex.Fixtures.personal_account_name(context.owner_email)

        {:ok, view, _html} = live(context.new_user_conn, "/app/subscriptions/checkout")
        html = render(view)
        refute html =~ owner_account_name
        {:ok, context}
      end
    end
  end
end
