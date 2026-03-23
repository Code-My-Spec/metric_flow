defmodule MetricFlowSpex.UserCanRevokeTheirOwnAccessFromClientAccountSettingsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "User can revoke their own access from client account settings" do
    scenario "a non-owner member sees a revoke access button on the account settings page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user to their account", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

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

      given_ "the second user logs in and accepts the invitation", context do
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
        |> element("[data-role='accept-btn']")
        |> render_click()

        {:ok, Map.put(context, :member_conn, authed_conn)}
      end

      when_ "the second user navigates to account settings", context do
        {:ok, view, _html} = live(context.member_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a revoke access button for the client account", context do
        html = render(context.view)
        assert html =~ "Revoke Access" or html =~ "Leave Account" or html =~ "revoke"
        :ok
      end
    end

    scenario "a non-owner member can revoke their own access from account settings" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user to their account", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

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

      given_ "the second user logs in and accepts the invitation", context do
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
        |> element("[data-role='accept-btn']")
        |> render_click()

        {:ok, Map.put(context, :member_conn, authed_conn)}
      end

      given_ "the second user is on the account settings page", context do
        {:ok, view, _html} = live(context.member_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the second user clicks the revoke access button and confirms", context do
        context.view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        context.view
        |> element("[data-role='confirm-leave']")
        |> render_click()

        {:ok, context}
      end

      then_ "the user sees a success message confirming access was revoked", context do
        html = render(context.view)
        assert html =~ "access has been revoked" or html =~ "You have left" or html =~ "revoked"
        :ok
      end
    end
  end
end
