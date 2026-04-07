defmodule MetricFlowSpex.UponAcceptanceUserAccountIsGrantedSpecifiedAccessLevelToClientAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "Upon acceptance, user account is granted specified access level to client account" do
    scenario "invited user accepts the invitation and gains the granted access level" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited the second user as account manager", context do
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

      given_ "the second user logs in", context do
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
        {:ok, Map.put(context, :invitee_conn, authed_conn)}
      end

      when_ "the second user visits and accepts the invitation", context do
        {:ok, view, _html} = live(context.invitee_conn, "/invitations/#{context.invitation_token}")

        view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, context}
      end

      then_ "the user sees a success confirmation message", context do
        {:ok, view, _html} = live(context.invitee_conn, "/app/accounts")
        html = render(view)
        assert html =~ "You now have access" or html =~ "Owner Account"
        :ok
      end

      then_ "the user can access the client account members page showing their role", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.second_user_email
        assert html =~ "account_manager"
        :ok
      end
    end

    scenario "invited user with read-only role accepts and sees appropriate access" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited the second user as read-only", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      given_ "the second user logs in", context do
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
        {:ok, Map.put(context, :invitee_conn, authed_conn)}
      end

      when_ "the second user accepts the invitation", context do
        {:ok, view, _html} = live(context.invitee_conn, "/invitations/#{context.invitation_token}")

        view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, context}
      end

      then_ "the user's role is shown as read_only in the members list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.second_user_email
        assert html =~ "read_only"
        :ok
      end
    end
  end
end
