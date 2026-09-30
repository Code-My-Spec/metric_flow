defmodule MetricFlowSpex.AutoEnrolledUserGetsTheConfiguredDefaultAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Auto-enrolled user gets the configured default access level", criterion: 592 do
    scenario "a newly auto-enrolled user's access level matches the agency's configured default" do
      given_ :agency_owner_logged_in

      given_ "the agency admin has set a default access level for auto-enrollment", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form",
          auto_enrollment: %{domain: "defaultlevel592.com", default_access_level: "account_manager"}
        )
        |> render_submit()

        {:ok, context}
      end

      when_ "a new user is auto-enrolled", context do
        registrant_email = "enrollee592@defaultlevel592.com"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: registrant_email,
            password: "SecurePassword123!",
            account_name: "Enrollee 592"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :registrant_email, registrant_email)}
      end

      then_ "the user's access level is set to that default", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.registrant_email
        assert html =~ "account_manager"
        {:ok, context}
      end
    end
  end
end
