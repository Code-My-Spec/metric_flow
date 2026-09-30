defmodule MetricFlowSpex.SignupViaValidAgencyInviteLinkStoresAgencyIdSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope

  spex "Signup via valid agency invite link stores agency_id", criterion: 482 do
    scenario "a new user who signs up through an agency's referral link is associated with that agency" do
      given_ :user_logged_in_as_owner

      when_ "a new user registers via the owner's referral link", context do
        owner_scope = Scope.for_user(MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email))
        owner_account_id = Accounts.get_personal_account_id(owner_scope)
        token = Agencies.generate_referral_token(owner_account_id)

        email = "jordan#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register?ref=#{token}")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Jordan's Account"}
        )
        |> render_submit()

        new_user_scope = Scope.for_user(MetricFlowTest.UsersFixtures.get_user_by_email(email))
        new_account_id = Accounts.get_personal_account_id(new_user_scope)

        {:ok, Map.merge(context, %{owner_account_id: owner_account_id, new_account_id: new_account_id})}
      end

      then_ "the new account's agency_id is the inviting agency's account", context do
        assert Agencies.find_client_agency_account_id(context.new_account_id) == context.owner_account_id
        {:ok, context}
      end
    end
  end
end
