defmodule MetricFlowSpex.AccountManagerAgencyUserSavesEditsAndDeletesDashboardsAndModifiesIntegrationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Account manager agency user saves, edits and deletes dashboards and modifies integrations",
    criterion: 602 do
    scenario "an account manager agency user can rename and delete a dashboard, and disconnect an integration" do
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

        dashboard = MetricFlowSpex.Fixtures.create_dashboard_for(email, "Client 602 Dashboard")
        MetricFlowSpex.Fixtures.create_integration_for(email, :google_ads)

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        acctmgr_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{acctmgr_conn: acctmgr_conn, dashboard_id: dashboard.id})}
      end

      when_ "they save, edit or delete a dashboard, or modify an integration, for that client",
            context do
        {:ok, index_view, _html} = live(context.acctmgr_conn, "/app/dashboards")

        index_view
        |> element("[data-role='rename-dashboard-#{context.dashboard_id}']")
        |> render_click()

        index_view
        |> form("[data-role='rename-form-#{context.dashboard_id}'] form", %{
          "name" => "Renamed by account manager"
        })
        |> render_submit()

        {:ok, integrations_view, _html} = live(context.acctmgr_conn, "/app/integrations")

        integrations_view
        |> element("[data-role='disconnect-integration']")
        |> render_click()

        integrations_view
        |> element("[data-role='confirm-disconnect']")
        |> render_click()

        {:ok, Map.merge(context, %{index_view: index_view, integrations_view: integrations_view})}
      end

      then_ "the change is applied", context do
        assert render(context.index_view) =~ "Renamed by account manager"
        refute has_element?(context.integrations_view, "[data-role='disconnect-integration']")
        {:ok, context}
      end
    end
  end
end
