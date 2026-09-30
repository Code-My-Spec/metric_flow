defmodule MetricFlowSpex.AccountManagerAgencyUserModifiesReportsAndIntegrationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Account manager agency user modifies reports and integrations", criterion: 602 do
    scenario "an account manager agency user can delete a report and disconnect an integration" do
      given_ "the agency has account manager access to a client account", context do
        email = "acctmgr602-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 602"}
        )
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        AgenciesFixtures.account_with_member_fixture(user, :account_manager)

        report = MetricFlowSpex.Fixtures.create_report_for(email, "Client 602 Report")

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        acctmgr_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{acctmgr_conn: acctmgr_conn, report_id: report.id})}
      end

      when_ "they modify a report or an integration for that client", context do
        {:ok, view, _html} = live(context.acctmgr_conn, "/app/reports")

        render_click(view, "delete", %{"id" => to_string(context.report_id)})
        html = render_click(view, "confirm_delete", %{"id" => to_string(context.report_id)})

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the change is saved", context do
        assert context.html =~ "Report deleted."
        {:ok, context}
      end
    end
  end
end
