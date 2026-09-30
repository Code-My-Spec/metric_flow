defmodule MetricFlowSpex.ReadOnlyAgencyUserCannotModifyReportsOrIntegrationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Read-only agency user cannot modify reports or integrations", criterion: 601 do
    scenario "a read-only agency user cannot delete a report or disconnect an integration" do
      given_ "the agency has read-only access to a client account", context do
        email = "readonly601-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 601"}
        )
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        AgenciesFixtures.account_with_member_fixture(user, :read_only)

        report = MetricFlowSpex.Fixtures.create_report_for(email, "Client 601 Report")
        MetricFlowSpex.Fixtures.create_integration_for(email, :google_ads)

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        readonly_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{readonly_conn: readonly_conn, report_id: report.id})}
      end

      when_ "they attempt to modify a report or integration for that client", context do
        {:ok, reports_view, _html} = live(context.readonly_conn, "/app/reports")
        {:ok, integrations_view, _html} = live(context.readonly_conn, "/app/integrations")

        {:ok,
         Map.merge(context, %{reports_view: reports_view, integrations_view: integrations_view})}
      end

      then_ "the action is rejected", context do
        refute has_element?(
                 context.reports_view,
                 "[data-role='delete-report-#{context.report_id}']"
               )

        refute has_element?(
                 context.integrations_view,
                 "[data-platform='google_ads'] [data-role='disconnect-integration']"
               )

        {:ok, context}
      end
    end
  end
end
