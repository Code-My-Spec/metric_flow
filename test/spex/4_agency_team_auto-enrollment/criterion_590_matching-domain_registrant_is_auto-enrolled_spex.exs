defmodule MetricFlowSpex.MatchingDomainRegistrantIsAutoEnrolledSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Matching-domain registrant is auto-enrolled", criterion: 590 do
    scenario "a new user registering on the exact configured domain is auto-enrolled" do
      given_ :agency_owner_logged_in

      given_ "an agency has configured auto-enrollment for a domain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "exactmatch590.com"})
        |> render_submit()

        {:ok, context}
      end

      when_ "a new user registers with an email address on that exact domain", context do
        registrant_email = "newuser590@exactmatch590.com"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: registrant_email,
            password: "SecurePassword123!",
            account_name: "New Registrant 590"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :registrant_email, registrant_email)}
      end

      then_ "the user is automatically added to the agency account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        assert render(view) =~ context.registrant_email
        {:ok, context}
      end
    end
  end
end
