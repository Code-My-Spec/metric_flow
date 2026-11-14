defmodule MetricFlowSpex.ReadOnlyAgencyUserCannotSaveEditOrDeleteDashboardsOrModifyIntegrationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Read-only agency user cannot save, edit or delete dashboards or modify integrations",
    criterion: 601 do
    scenario "a read-only agency user cannot delete a dashboard, open its editor, or disconnect an integration" do
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

        dashboard = MetricFlowSpex.Fixtures.create_dashboard_for(email, "Client 601 Dashboard")
        MetricFlowSpex.Fixtures.create_integration_for(email, :google_ads)

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        readonly_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{readonly_conn: readonly_conn, dashboard_id: dashboard.id})}
      end

      when_ "they attempt to save, edit or delete a dashboard, or modify an integration, for that client",
            context do
        {:ok, index_view, _html} = live(context.readonly_conn, "/app/dashboards")

        edit_result = live(context.readonly_conn, "/app/dashboards/#{context.dashboard_id}/edit")

        render_click(index_view, "confirm_delete", %{"id" => to_string(context.dashboard_id)})

        {:ok, integrations_view, _html} = live(context.readonly_conn, "/app/integrations")

        {:ok,
         Map.merge(context, %{
           index_view: index_view,
           edit_result: edit_result,
           integrations_view: integrations_view
         })}
      end

      then_ "the action is rejected", context do
        assert {:error, {:redirect, %{to: "/app/dashboards"}}} = context.edit_result

        assert has_element?(
                 context.index_view,
                 "[data-role='edit-dashboard-#{context.dashboard_id}']"
               )

        refute has_element?(context.integrations_view, "[data-role='disconnect-integration']")

        {:ok, context}
      end
    end
  end
end
