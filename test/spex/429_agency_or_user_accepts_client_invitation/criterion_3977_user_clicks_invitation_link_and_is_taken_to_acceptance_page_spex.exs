defmodule MetricFlowSpex.UserClicksInvitationLinkAndIsTakenToAcceptancePageSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "User clicks invitation link and is taken to acceptance page" do
    scenario "logged-in user visits a valid invitation link and sees the acceptance page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation to the second user", context do
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

      when_ "the second user visits the invitation acceptance URL", context do
        {:ok, view, _html} = live(context.invitee_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees the invitation acceptance page", context do
        html = render(context.view)
        assert html =~ "invited"
        :ok
      end

      then_ "the page shows the client account details for the invitation", context do
        html = render(context.view)
        assert html =~ "Owner Account"
        :ok
      end
    end

    scenario "unauthenticated user visits an invitation link and is shown the acceptance page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation", context do
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

      when_ "an unauthenticated user visits the invitation URL", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees the invitation acceptance page", context do
        html = render(context.view)
        assert html =~ "invited"
        :ok
      end
    end
  end
end
