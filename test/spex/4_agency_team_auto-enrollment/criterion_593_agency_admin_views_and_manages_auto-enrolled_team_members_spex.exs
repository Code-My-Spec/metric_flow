defmodule MetricFlowSpex.AgencyAdminViewsAndManagesAutoEnrolledTeamMembersSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency admin views and manages auto-enrolled team members", criterion: 593 do
    scenario "the agency admin opens the team management view and sees auto-enrolled members" do
      given_ :agency_owner_logged_in

      given_ "the agency has auto-enrolled team members", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "teamview593.com"})
        |> render_submit()

        registrant_email = "member593@teamview593.com"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: registrant_email,
            password: "SecurePassword123!",
            account_name: "Member 593"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :registrant_email, registrant_email)}
      end

      when_ "the agency admin opens the team management view", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :members_view, view)}
      end

      then_ "they see all auto-enrolled members and can manage their access", context do
        html = render(context.members_view)
        assert html =~ context.registrant_email

        assert has_element?(
                 context.members_view,
                 "[data-role='change-role'][data-user-email='#{context.registrant_email}']"
               ),
               "Expected a way to manage the auto-enrolled member's access"

        {:ok, context}
      end
    end
  end
end
