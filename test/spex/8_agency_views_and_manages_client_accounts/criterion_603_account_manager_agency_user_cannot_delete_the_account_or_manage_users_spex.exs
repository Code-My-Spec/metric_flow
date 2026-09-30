defmodule MetricFlowSpex.AccountManagerAgencyUserCannotDeleteTheAccountOrManageUsersSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Account manager agency user cannot delete the account or manage users", criterion: 603 do
    scenario "an account manager agency user has no delete-account or manage-users controls" do
      given_ "the agency has account manager access to a client account", context do
        email = "acctmgr603-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 603"}
        )
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        AgenciesFixtures.account_with_member_fixture(user, :account_manager)

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        acctmgr_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.put(context, :acctmgr_conn, acctmgr_conn)}
      end

      when_ "they attempt to delete the account or manage its users", context do
        {:ok, settings_view, _html} = live(context.acctmgr_conn, "/app/accounts/settings")
        {:ok, members_view, _html} = live(context.acctmgr_conn, "/app/accounts/members")

        {:ok, Map.merge(context, %{settings_view: settings_view, members_view: members_view})}
      end

      then_ "the action is rejected", context do
        refute has_element?(context.settings_view, "[data-role='delete-account']")
        refute has_element?(context.members_view, "[data-role='members-list']")
        {:ok, context}
      end
    end
  end
end
