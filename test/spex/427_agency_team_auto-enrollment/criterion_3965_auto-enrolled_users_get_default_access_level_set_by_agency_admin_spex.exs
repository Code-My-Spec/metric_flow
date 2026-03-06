defmodule MetricFlowSpex.AutoEnrolledUsersGetDefaultAccessLevelSetByAgencyAdminSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Auto-enrolled users get default access level set by agency admin" do
    scenario "agency admin can configure a default access level for auto-enrolled users on the settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner sees a default role selector in the auto-enrollment section", context do
        assert has_element?(context.view, "[data-role='auto-enrollment-default-role']")
        :ok
      end

      when_ "the owner selects read_only as the default role and saves", context do
        domain = "scenario1-#{System.unique_integer([:positive])}.com"

        context.view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: domain,
          default_access_level: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :domain, domain)}
      end

      then_ "a success confirmation is shown that the default role has been saved", context do
        assert render(context.view) =~ "Auto-enrollment enabled"
        :ok
      end

      then_ "the saved default role read_only is shown on the settings page", context do
        assert render(context.view) =~ "read_only"
        :ok
      end
    end

    scenario "auto-enrolled user receives the configured default role visible on the members page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has configured auto-enrollment for a unique domain with default role read_only", context do
        domain = "autoenroll-#{System.unique_integer([:positive])}.com"

        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: domain,
          default_access_level: "read_only"
        })
        |> render_submit()

        {:ok, Map.merge(context, %{settings_view: view, enrollment_domain: domain})}
      end

      given_ "a new user registers with an email matching the configured domain", context do
        employee_email = "employee#{System.unique_integer([:positive])}@#{context.enrollment_domain}"
        employee_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: employee_email,
          password: employee_password,
          account_name: "Employee Account"
        })
        |> render_submit()

        {:ok, Map.merge(context, %{employee_email: employee_email, employee_password: employee_password})}
      end

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :members_view, view)}
      end

      then_ "the auto-enrolled user appears in the members list", context do
        html = render(context.members_view)
        assert html =~ context.employee_email
        :ok
      end

      then_ "the auto-enrolled user's role is displayed as read_only", context do
        html = render(context.members_view)
        assert html =~ context.employee_email
        assert html =~ "read_only"
        :ok
      end
    end
  end
end
