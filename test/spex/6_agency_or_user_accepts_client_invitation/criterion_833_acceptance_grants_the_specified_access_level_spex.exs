defmodule MetricFlowSpex.Criterion833AcceptanceGrantsTheSpecifiedAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Acceptance grants the specified access level", criterion: 833 do
    scenario "accepting an invitation grants the invitee the role it specified" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited the second user as account manager", context do
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

      when_ "the second user accepts the invitation", context do
        {:ok, view, _html} = live(context.invitee_conn, "/invitations/#{context.invitation_token}")

        view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, context}
      end

      then_ "the members list shows the invitee with the specified access level", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.second_user_email
        assert html =~ "account_manager"
        {:ok, context}
      end
    end
  end
end
