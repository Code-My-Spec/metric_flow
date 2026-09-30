defmodule MetricFlowSpex.AutoEnrolledMemberInheritsAccessToAllAgencyClientAccountsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Auto-enrolled member inherits access to all agency client accounts", criterion: 595 do
    scenario "a user auto-enrolled into an agency that manages client accounts gets access to all of them" do
      given_ :agency_owner_logged_in

      given_ "the agency has configured auto-enrollment and manages two client accounts", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        agency_domain = "inherits595-#{System.unique_integer([:positive])}.com"

        view
        |> form("#auto-enrollment-form",
          auto_enrollment: %{domain: agency_domain, default_access_level: "read_only"}
        )
        |> render_submit()

        client1 = MetricFlowSpex.Fixtures.client_account_fixture("Client 595 Alpha")
        client2 = MetricFlowSpex.Fixtures.client_account_fixture("Client 595 Beta")

        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client1.id, :admin, true)
        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client2.id, :admin, true)

        {:ok,
         Map.merge(context, %{
           agency_domain: agency_domain,
           client_account_1: "Client 595 Alpha",
           client_account_2: "Client 595 Beta"
         })}
      end

      when_ "a user registers with an email matching the agency domain and is auto-enrolled", context do
        member_email = "newmember595@#{context.agency_domain}"
        member_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: member_email, password: member_password, account_name: "Member 595"}
        )
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: member_email, password: member_password, remember_me: true}
          )

        member_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, view, _html} = live(member_conn, "/app/accounts")
        {:ok, Map.put(context, :member_accounts_view, view)}
      end

      then_ "the user automatically has access to all of the agency's client accounts without a separate per-client invite",
            context do
        html = render(context.member_accounts_view)
        assert html =~ context.client_account_1
        assert html =~ context.client_account_2
        {:ok, context}
      end
    end
  end
end
