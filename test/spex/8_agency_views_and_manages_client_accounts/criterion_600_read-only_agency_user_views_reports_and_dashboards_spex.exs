defmodule MetricFlowSpex.ReadOnlyAgencyUserViewsReportsAndDashboardsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Read-only agency user views reports and dashboards", criterion: 600 do
    scenario "a read-only agency user can view that client's reports" do
      given_ "the agency has read-only access to a client account", context do
        email = "readonly600-#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: email, password: password, account_name: "Personal 600"}
        )
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        AgenciesFixtures.account_with_member_fixture(user, :read_only)

        MetricFlowSpex.Fixtures.create_report_for(email, "Client 600 Report")

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: email, password: password, remember_me: true}
          )

        readonly_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.put(context, :readonly_conn, readonly_conn)}
      end

      when_ "they view that client's reports and dashboards", context do
        {:ok, view, _html} = live(context.readonly_conn, "/app/reports")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can see them", context do
        assert render(context.view) =~ "Client 600 Report"
        {:ok, context}
      end
    end
  end
end
