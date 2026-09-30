defmodule MetricFlowSpex.Criterion837AgencyInviteesTeamGainsAccessPerTheAgencysTeamStructureSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Agency invitee's team gains access per the agency's team structure", criterion: 837 do
    scenario "an agency user accepting a client invitation is granted access reflected in the client's member list" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the client has invited the agency user", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: context.second_user_email,
            role: "account_manager"
          }
        )
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      given_ "the agency user logs in", context do
        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{
              email: context.second_user_email,
              password: context.second_user_password,
              remember_me: true
            }
          )

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)
        {:ok, Map.put(context, :agency_user_conn, authed_conn)}
      end

      when_ "the agency user accepts the client invitation", context do
        {:ok, view, _html} = live(context.agency_user_conn, "/invitations/#{context.invitation_token}")

        view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, context}
      end

      then_ "the client account's member list reflects the agency user's granted access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.second_user_email
        assert html =~ "account_manager"
        {:ok, context}
      end

      then_ "the agency user sees the client account in their own account list", context do
        {:ok, view, _html} = live(context.agency_user_conn, "/app/accounts")
        html = render(view)
        assert html =~ "Owner Account"
        {:ok, context}
      end
    end
  end
end
