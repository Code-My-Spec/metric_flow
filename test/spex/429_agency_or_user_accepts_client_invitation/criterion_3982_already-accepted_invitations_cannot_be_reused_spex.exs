defmodule MetricFlowSpex.AlreadyAcceptedInvitationsCannotBeReusedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "Already-accepted invitations cannot be reused" do
    scenario "user tries to use an already-accepted invitation and sees an error" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited the second user", context do
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

      given_ "the second user has already accepted the invitation", context do
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

        {:ok, Map.put(context, :invitee_conn, authed_conn)}
      end

      when_ "the second user tries to visit the same invitation link again", context do
        result = live(context.invitee_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "the user sees a message indicating the invitation has already been used", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "invalid or has already been used"
        :ok
      end

      then_ "the accept button is not shown for the already-used invitation", context do
        # The redirect means no LiveView is rendered, so there is no accept button
        :ok
      end
    end

    scenario "a third user cannot reuse another person's accepted invitation" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited the second user", context do
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

      given_ "the second user has accepted the invitation", context do
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

        {:ok, context}
      end

      when_ "the original owner tries to visit the same invitation link", context do
        result = live(context.owner_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "the owner sees that the invitation is no longer valid", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "invalid or has already been used"
        :ok
      end
    end
  end
end
