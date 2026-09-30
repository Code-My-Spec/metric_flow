defmodule MetricFlowSpex.DomainAlreadyClaimedByAnotherAgencyIsRejectedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Domain already claimed by another agency is rejected", criterion: 589 do
    scenario "a second agency cannot configure a domain already claimed by another agency" do
      given_ :agency_owner_logged_in

      given_ "an email domain is already configured for auto-enrollment by a different agency", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "claimed589.com"})
        |> render_submit()

        second_email = "second589-#{System.unique_integer([:positive])}@example.com"
        second_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: second_email,
            password: second_password,
            account_name: "Second Agency 589",
            account_type: "agency"
          }
        )
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: second_email, password: second_password, remember_me: true}
          )

        second_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.put(context, :second_conn, second_conn)}
      end

      when_ "an agency owner tries to configure that same domain for their own agency", context do
        {:ok, second_view, _html} = live(context.second_conn, "/app/accounts/settings")

        second_view
        |> form("#auto-enrollment-form", auto_enrollment: %{domain: "claimed589.com"})
        |> render_submit()

        {:ok, Map.put(context, :second_view, second_view)}
      end

      then_ "the configuration is rejected with an explanation that the domain is already in use",
            context do
        html = render(context.second_view)

        assert html =~ "already been taken" or html =~ "already in use",
               "Expected an explanation that the domain is already claimed, got: #{html}"

        {:ok, context}
      end
    end
  end
end
