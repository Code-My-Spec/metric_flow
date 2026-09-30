defmodule MetricFlowSpex.Criterion34InvitationLinkIsSingleUseAndInvalidatedAfterAcceptanceOrExpirationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation link is single-use and invalidated after acceptance or expiration",
    criterion: 34 do
    scenario "an invitation link cannot be reused after it has already been accepted" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user, who accepts it", context do
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

      when_ "anyone tries to visit the same invitation link again", context do
        result = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :second_visit_result, result)}
      end

      then_ "the link is invalidated and cannot be used again", context do
        assert {:error, {:redirect, %{flash: flash}}} = context.second_visit_result
        assert flash["error"] =~ "invalid or has already been used"
        {:ok, context}
      end
    end

    scenario "an expired invitation link cannot be used" do
      given_ :user_logged_in_as_owner

      given_ "the owner sends an invitation that has since expired", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "expired-link@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            token
          end)

        MetricFlowSpex.Fixtures.expire_invitation!(token)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the invitee tries to use the expired link", context do
        result = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :visit_result, result)}
      end

      then_ "the invitee sees the invitation has expired", context do
        assert {:error, {:redirect, %{flash: flash}}} = context.visit_result
        assert flash["error"] =~ "expired"
        {:ok, context}
      end
    end
  end
end
