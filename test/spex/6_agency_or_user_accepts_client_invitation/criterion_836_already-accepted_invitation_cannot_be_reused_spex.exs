defmodule MetricFlowSpex.Criterion836AlreadyAcceptedInvitationCannotBeReusedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Already-accepted invitation cannot be reused", criterion: 836 do
    scenario "revisiting an already-accepted invitation link fails with a clear message" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited the second user", context do
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

      given_ "the second user has already accepted the invitation", context do
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

        {:ok, accept_view, _html} = live(authed_conn, "/invitations/#{context.invitation_token}")

        accept_view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, Map.put(context, :invitee_conn, authed_conn)}
      end

      when_ "the invitee revisits the same invitation link", context do
        result = live(context.invitee_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "a clear message says the invitation cannot be reused", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "invalid or has already been used"
        {:ok, context}
      end
    end
  end
end
