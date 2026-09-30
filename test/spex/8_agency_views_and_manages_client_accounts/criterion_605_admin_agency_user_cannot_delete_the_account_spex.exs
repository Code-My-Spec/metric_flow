defmodule MetricFlowSpex.AdminAgencyUserCannotDeleteTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Admin agency user cannot delete the account", criterion: 605 do
    scenario "an admin agency user has no delete-account control for that client account" do
      given_ "the agency has admin access to a client account", context do
        email = "admin605-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 605"}
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

      when_ "they attempt to delete that client account", context do
        {:ok, settings_view, _html} = live(context.admin_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      then_ "the action is rejected", context do
        refute has_element?(context.settings_view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
