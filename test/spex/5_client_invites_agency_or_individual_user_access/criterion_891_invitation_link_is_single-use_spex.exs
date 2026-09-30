defmodule MetricFlowSpex.Criterion891InvitationLinkIsSingleUseSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation link is single-use", criterion: 891 do
    scenario "an accepted invitation link cannot be used a second time by anyone" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "an invitation has been accepted", context do
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
            [_, token] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            token
          end)

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

        {:ok, accept_view, _html} = live(authed_conn, "/invitations/#{token}")

        accept_view
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "anyone attempts to use the same invitation link again", context do
        result = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "it is invalidated and cannot be reused", context do
        assert {:error, {:redirect, %{flash: flash}}} = context.result
        assert flash["error"] =~ "invalid or has already been used"
        {:ok, context}
      end
    end
  end
end
