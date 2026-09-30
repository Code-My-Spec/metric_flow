defmodule MetricFlowSpex.Criterion831InvitationLinkOpensTheAcceptancePageSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation link opens the acceptance page", criterion: 831 do
    scenario "clicking a valid invitation link opens the acceptance page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation to the second user", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: context.second_user_email,
            role: "read_only"
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

      given_ "the second user logs in", context do
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
        {:ok, Map.put(context, :invitee_conn, authed_conn)}
      end

      when_ "the invitee opens the invitation link", context do
        {:ok, view, _html} = live(context.invitee_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the acceptance page is shown", context do
        html = render(context.view)
        assert html =~ "invited"
        {:ok, context}
      end

      then_ "the page identifies the inviting client account", context do
        html = render(context.view)
        assert html =~ "Owner Account"
        {:ok, context}
      end
    end
  end
end
