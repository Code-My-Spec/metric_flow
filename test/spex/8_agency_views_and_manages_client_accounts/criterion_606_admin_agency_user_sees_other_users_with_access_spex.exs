defmodule MetricFlowSpex.AdminAgencyUserSeesOtherUsersWithAccessSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Admin agency user sees other users with access", criterion: 606 do
    scenario "an admin agency user can view the client account's access list" do
      given_ "the agency has admin access to a client account", context do
        email = "admin606-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 606"}
        )
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        AgenciesFixtures.account_with_member_fixture(user, :admin)

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        admin_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.put(context, :admin_conn, admin_conn)}
      end

      when_ "they view that client's access list", context do
        {:ok, view, _html} = live(context.admin_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see the other users who have access to the account", context do
        assert has_element?(context.view, "[data-role='members-list']")
        assert has_element?(context.view, "[data-role='member-row']")
        {:ok, context}
      end
    end
  end
end
