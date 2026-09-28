defmodule MetricFlowSpex.TeamMembersAutomaticallyInheritAccessToAllClientAccountsTheAgencyManagesSpex do
  use MetricFlowSpex.Case

  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Team members automatically inherit access to all client accounts the agency manages" do
    scenario "auto-enrolled team member can see all client accounts the agency manages on the accounts page" do
      given_(:user_logged_in_as_owner)

      given_ "the owner has configured auto-enrollment and added client accounts", context do
        # Configure auto-enrollment via the UI
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        agency_domain = "agencydomain#{System.unique_integer([:positive])}.com"

        view
        |> form("#auto-enrollment-form",
          auto_enrollment: %{
            domain: agency_domain,
            default_access_level: "read_only"
          }
        )
        |> render_submit()

        # Set up client accounts via domain layer (client account management UI is a separate story)
        client1 = MetricFlowTest.AgenciesFixtures.account_fixture(%{name: "Client Alpha"})
        client2 = MetricFlowTest.AgenciesFixtures.account_fixture(%{name: "Client Beta"})

        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client1.id, :admin, true)
        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client2.id, :admin, true)

        {:ok,
         Map.merge(context, %{
           agency_domain: agency_domain,
           client_account_1: "Client Alpha",
           client_account_2: "Client Beta"
         })}
      end

      given_ "a new user registers with an email matching the agency domain", context do
        member_email = "newmember#{System.unique_integer([:positive])}@#{context.agency_domain}"
        member_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: member_email,
            password: member_password,
            account_name: "Member Personal Account"
          }
        )
        |> render_submit()

        {:ok, Map.merge(context, %{member_email: member_email, member_password: member_password})}
      end

      when_ "the new auto-enrolled member logs in and navigates to the accounts page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{
              email: context.member_email,
              password: context.member_password,
              remember_me: true
            }
          )

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)

        {:ok, view, _html} = live(member_conn, "/app/accounts")
        {:ok, Map.merge(context, %{member_conn: member_conn, accounts_view: view})}
      end

      then_ "the auto-enrolled member sees the first client account on the accounts page",
            context do
        html = render(context.accounts_view)
        assert html =~ context.client_account_1
        {:ok, context}
      end

      then_ "the auto-enrolled member sees the second client account on the accounts page",
            context do
        html = render(context.accounts_view)
        assert html =~ context.client_account_2
        {:ok, context}
      end
    end

    scenario "auto-enrolled team member's access to client accounts reflects their assigned role" do
      given_(:user_logged_in_as_owner)

      given_ "the owner has configured auto-enrollment and added a client account", context do
        # Configure auto-enrollment via the UI
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        agency_domain = "agencyroles#{System.unique_integer([:positive])}.com"

        view
        |> form("#auto-enrollment-form",
          auto_enrollment: %{
            domain: agency_domain,
            default_access_level: "read_only"
          }
        )
        |> render_submit()

        # Set up client account via domain layer (client account management UI is a separate story)
        client = MetricFlowTest.AgenciesFixtures.account_fixture(%{name: "Managed Client Corp"})

        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client.id, :admin, true)

        {:ok,
         Map.merge(context, %{
           agency_domain: agency_domain,
           client_account_name: "Managed Client Corp"
         })}
      end

      given_ "a new user registers with an email matching the agency domain", context do
        member_email = "rolemember#{System.unique_integer([:positive])}@#{context.agency_domain}"
        member_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{
            email: member_email,
            password: member_password,
            account_name: "Role Member Account"
          }
        )
        |> render_submit()

        {:ok, Map.merge(context, %{member_email: member_email, member_password: member_password})}
      end

      when_ "the auto-enrolled member logs in and navigates to the accounts page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{
              email: context.member_email,
              password: context.member_password,
              remember_me: true
            }
          )

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)

        {:ok, view, _html} = live(member_conn, "/app/accounts")
        {:ok, Map.merge(context, %{member_conn: member_conn, accounts_view: view})}
      end

      then_ "the client account is listed in the member's accounts view", context do
        html = render(context.accounts_view)
        assert html =~ context.client_account_name
        {:ok, context}
      end

      then_ "the member's access level for the client account is shown as read_only", context do
        html = render(context.accounts_view)
        assert html =~ context.client_account_name
        assert html =~ "read_only"
        {:ok, context}
      end
    end
  end
end
