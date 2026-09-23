defmodule MetricFlowSpex.AgencyAdminCanViewAndManageAllAutoEnrolledTeamMembersSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admin can view and manage all auto-enrolled team members" do
    scenario "auto-enrolled team members appear in the members list on the account members page" do
      given_ :user_logged_in_as_owner

      given_ "the owner configures auto-enrollment for domain agencyco.com", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: "agencyco.com"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "a new user registers with an email matching the configured domain", context do
        employee_email = "employee#{System.unique_integer([:positive])}@agencyco.com"
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
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :members_view, view)}
      end

      then_ "the auto-enrolled user appears in the members list", context do
        html = render(context.members_view)
        assert html =~ context.employee_email
        :ok
      end

      then_ "the members list shows the Member column header", context do
        html = render(context.members_view)
        assert html =~ "Member"
        :ok
      end

      then_ "the members list shows the Role column header", context do
        html = render(context.members_view)
        assert html =~ "Role"
        :ok
      end

      then_ "the members list shows the Actions column header", context do
        html = render(context.members_view)
        assert html =~ "Actions"
        :ok
      end
    end

    scenario "agency admin can change the role of an auto-enrolled team member" do
      given_ :user_logged_in_as_owner

      given_ "the owner configures auto-enrollment for domain staffco.com", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: "staffco.com",
          default_access_level: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "a new user registers with an email matching the configured domain", context do
        staff_email = "staff#{System.unique_integer([:positive])}@staffco.com"
        staff_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: staff_email,
          password: staff_password,
          account_name: "Staff Account"
        })
        |> render_submit()

        {:ok, Map.merge(context, %{staff_email: staff_email, staff_password: staff_password})}
      end

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :members_view, view)}
      end

      then_ "the auto-enrolled staff member appears in the members list", context do
        html = render(context.members_view)
        assert html =~ context.staff_email
        :ok
      end

      when_ "the owner changes the auto-enrolled member's role to account_manager", context do
        context.members_view
        |> element("[data-role='change-role'][data-user-email='#{context.staff_email}']")
        |> render_click(%{role: "account_manager"})

        {:ok, context}
      end

      then_ "the auto-enrolled member's role is updated to account_manager in the list", context do
        html = render(context.members_view)
        assert html =~ context.staff_email
        assert html =~ "account_manager"
        :ok
      end

      then_ "a success message is displayed confirming the role change", context do
        assert render(context.members_view) =~ "Role updated"
        :ok
      end
    end
  end
end
