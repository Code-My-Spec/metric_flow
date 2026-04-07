defmodule MetricFlowSpex.IfInviteeIsPartOfAgencyEntireAgencyTeamGetsAccessSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "If invitee is part of an agency, entire agency team gets access based on agency team structure" do
    scenario "agency user accepts an invitation and the client account appears in their account list" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user is an agency user who has been invited", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
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
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)
        {:ok, Map.put(context, :agency_user_conn, authed_conn)}
      end

      when_ "the agency user accepts the client invitation", context do
        {:ok, view, _html} = live(context.agency_user_conn, "/invitations/#{context.invitation_token}")

        result =
          view
          |> element("[data-role=accept-btn]")
          |> render_click()

        {:ok, Map.put(context, :accept_result, result)}
      end

      then_ "the agency user sees the client account in their accounts list", context do
        {:ok, view, _html} = live(context.agency_user_conn, "/app/accounts")
        html = render(view)
        assert html =~ "Owner Account"
        :ok
      end

      then_ "a success confirmation is shown after accepting", context do
        {:ok, view, _html} = live(context.agency_user_conn, "/app/accounts")
        html = render(view)
        assert html =~ "You now have access" or html =~ "Owner Account"
        :ok
      end
    end

    scenario "agency account members page reflects the new client account access" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the client has invited the agency user", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      given_ "the agency user logs in and accepts the invitation", context do
        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, accept_view, _html} = live(authed_conn, "/invitations/#{context.invitation_token}")

        accept_view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, Map.put(context, :agency_user_conn, authed_conn)}
      end

      then_ "the client account members list shows the agency user has access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.second_user_email
        assert html =~ "account_manager"
        :ok
      end
    end

    scenario "agency account shows the client account as a managed account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the client has invited the agency user and they accepted", context do
        {:ok, invite_view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        invite_view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, accept_view, _html} = live(authed_conn, "/invitations/#{token}")

        accept_view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, Map.put(context, :agency_user_conn, authed_conn)}
      end

      then_ "the agency user sees the client account listed under their accessible accounts", context do
        {:ok, view, _html} = live(context.agency_user_conn, "/app/accounts")
        html = render(view)
        assert html =~ "Owner Account"
        :ok
      end
    end
  end
end
