defmodule MetricFlowSpex.SignupWithExpiredOrInvalidReferralTokenProceedsWithoutAgencyAssociationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope

  spex "Signup with expired or invalid referral token proceeds without agency association", criterion: 483 do
    scenario "a user who registers with an invalid referral token is not tied to any agency" do
      given_ :user_logged_in_as_owner

      when_ "a new user registers with a garbled referral token", context do
        email = "outsider#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register?ref=not-a-real-token")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Outsider Account"}
        )
        |> render_submit()

        new_user_scope = Scope.for_user(MetricFlowTest.UsersFixtures.get_user_by_email(email))
        new_account_id = Accounts.get_personal_account_id(new_user_scope)

        {:ok, Map.put(context, :new_account_id, new_account_id)}
      end

      then_ "the account proceeds independently, with no agency association stored", context do
        assert Agencies.find_client_agency_account_id(context.new_account_id) == nil
        {:ok, context}
      end
    end
  end
end
