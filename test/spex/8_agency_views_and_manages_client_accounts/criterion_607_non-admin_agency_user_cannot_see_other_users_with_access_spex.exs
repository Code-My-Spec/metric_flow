defmodule MetricFlowSpex.NonAdminAgencyUserCannotSeeOtherUsersWithAccessSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Non-admin agency user cannot see other users with access", criterion: 607 do
    scenario "an account manager agency user cannot see the client account's access list" do
      given_ "the agency has read-only or account manager access to a client account", context do
        email = "acctmgr607-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 607"}
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

      when_ "they try to view that client's access list", context do
        {:ok, view, _html} = live(context.acctmgr_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they cannot see who else has access", context do
        refute has_element?(context.view, "[data-role='members-list']")
        refute has_element?(context.view, "[data-role='member-row']")
        {:ok, context}
      end
    end
  end
end
