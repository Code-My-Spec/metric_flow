defmodule MetricFlowSpex.AgencyUserAssociatedViaInviteSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope

  spex "User who signs up via an agency invite link is associated with that agency", criterion: 427 do
    scenario "a new user registers through the agency's referral link" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      when_ "a new user registers via the owner's referral link", context do
        owner_scope = Scope.for_user(MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email))
        owner_account_id = Accounts.get_personal_account_id(owner_scope)
        token = Agencies.generate_referral_token(owner_account_id)

        email = "referred#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register?ref=#{token}")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Referred Account"}
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

      then_ "the new user's checkout reflects the referring agency's plan", context do
        {:ok, view, _html} = live(context.new_user_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ context.agency_plan.name
        {:ok, context}
      end
    end
  end
end
