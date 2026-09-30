defmodule MetricFlowSpex.AdminAgencyUserCanDoEverythingExceptDeleteTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Admin agency user can do everything except delete the account", criterion: 604 do
    scenario "an admin agency user can modify reports, integrations, and manage users for that client" do
      given_ "the agency has admin access to a client account", context do
        email = "admin604-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 604"}
        )
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        AgenciesFixtures.account_with_member_fixture(user, :admin)

        report = MetricFlowSpex.Fixtures.create_report_for(email, "Client 604 Report")

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        admin_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{admin_conn: admin_conn, report_id: report.id})}
      end

      when_ "they modify reports, integrations, and users for that client", context do
        {:ok, reports_view, _html} = live(context.admin_conn, "/app/reports")

        render_click(reports_view, "delete", %{"id" => to_string(context.report_id)})

        delete_html =
          render_click(reports_view, "confirm_delete", %{"id" => to_string(context.report_id)})

        {:ok, members_view, _html} = live(context.admin_conn, "/app/accounts/members")

        {:ok, Map.merge(context, %{delete_html: delete_html, members_view: members_view})}
      end

      then_ "all of those actions succeed", context do
        assert context.delete_html =~ "Report deleted."
        assert has_element?(context.members_view, "[data-role='members-list']")
        {:ok, context}
      end
    end
  end
end
