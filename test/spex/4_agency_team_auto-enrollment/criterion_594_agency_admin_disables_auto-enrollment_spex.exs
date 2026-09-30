defmodule MetricFlowSpex.AgencyAdminDisablesAutoEnrollmentSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency admin disables auto-enrollment", criterion: 594 do
    scenario "disabling auto-enrollment stops new matching-domain registrations from being enrolled" do
      given_ :agency_owner_logged_in

      given_ "auto-enrollment is currently enabled for the agency's domain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "disableme594.com"})
        |> render_submit()

        {:ok, Map.put(context, :settings_view, view)}
      end

      when_ "the agency admin disables it", context do
        context.settings_view
        |> element("[data-role='disable-auto-enrollment']")
        |> render_click()

        {:ok, context}
      end

      then_ "new registrations with that domain are no longer auto-enrolled", context do
        registrant_email = "toolate594@disableme594.com"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: registrant_email,
            password: "SecurePassword123!",
            account_name: "Too Late 594"
          }
        )
        |> render_submit()

        {:ok, members_view, _html} = live(context.owner_conn, "/app/accounts/members")
        refute render(members_view) =~ registrant_email
        {:ok, context}
      end
    end
  end
end
