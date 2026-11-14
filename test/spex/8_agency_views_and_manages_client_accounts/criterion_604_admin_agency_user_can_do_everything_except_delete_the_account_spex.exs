defmodule MetricFlowSpex.AdminAgencyUserCanDoEverythingExceptDeleteTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  # Rule wording unchanged ("modify reports, integrations, and users") -- the
  # scenario's own reports action moved to dashboards, the retirement's actual
  # write surface (Story 75), since /app/reports no longer exists for anyone.
  spex "Admin agency user can do everything except delete the account", criterion: 604 do
    scenario "an admin agency user can modify dashboards, integrations, and view users for that client" do
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

        dashboard = MetricFlowSpex.Fixtures.create_dashboard_for(email, "Client 604 Dashboard")
        MetricFlowSpex.Fixtures.create_integration_for(email, :google_ads)

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        admin_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{admin_conn: admin_conn, dashboard_id: dashboard.id})}
      end

      when_ "they modify dashboards, integrations, and users for that client", context do
        {:ok, index_view, _html} = live(context.admin_conn, "/app/dashboards")

        delete_html =
          render_click(index_view, "confirm_delete", %{"id" => to_string(context.dashboard_id)})

        {:ok, integrations_view, _html} = live(context.admin_conn, "/app/integrations")

        integrations_view
        |> element("[data-role='disconnect-integration']")
        |> render_click()

        disconnect_html =
          integrations_view
          |> element("[data-role='confirm-disconnect']")
          |> render_click()

        {:ok, members_view, _html} = live(context.admin_conn, "/app/accounts/members")

        {:ok,
         Map.merge(context, %{
           delete_html: delete_html,
           disconnect_html: disconnect_html,
           members_view: members_view
         })}
      end

      then_ "all of those actions succeed", context do
        assert context.delete_html =~ "Dashboard deleted."
        assert context.disconnect_html =~ "Disconnected from Google Ads."
        assert has_element?(context.members_view, "[data-role='members-list']")
        {:ok, context}
      end
    end
  end
end
