defmodule MetricFlowSpex.SubdomainRegistrantIsNotAutoEnrolledSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Subdomain registrant is not auto-enrolled", criterion: 591 do
    scenario "a user registering on a subdomain of the configured domain is not auto-enrolled" do
      given_ :agency_owner_logged_in

      given_ "an agency has configured auto-enrollment for a domain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "parentdomain591.com"})
        |> render_submit()

        {:ok, context}
      end

      when_ "a user registers with an email address on a subdomain of that domain rather than an exact match",
            context do
        registrant_email = "subuser591@team.parentdomain591.com"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: registrant_email,
            password: "SecurePassword123!",
            account_name: "Subdomain Registrant 591"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :registrant_email, registrant_email)}
      end

      then_ "the user is not auto-enrolled", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        refute render(view) =~ context.registrant_email
        {:ok, context}
      end
    end
  end
end
