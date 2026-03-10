defmodule MetricFlowSpex.UserSeesClientAccountAddedToTheirAccountSwitcherOrListSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "User sees client account added to their account switcher or list" do
    scenario "after accepting an invitation, the client account appears in the account switcher" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation to the second user", context do
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

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner's account name appears in the second user's account list", context do
        {:ok, view, _html} = live(context.invitee_conn, "/accounts")
        html = render(view)
        assert html =~ "Owner Account"
        :ok
      end
    end

    scenario "after accepting an invitation, the client account is accessible via account switcher" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation to the second user", context do
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
        |> element("[data-role=accept-btn]")
        |> render_click()

        {:ok, Map.put(context, :invitee_conn, authed_conn)}
      end

      then_ "the navigation shows the account switcher with both accounts", context do
        {:ok, view, _html} = live(context.invitee_conn, "/accounts")
        html = render(view)
        assert html =~ "Owner Account"
        :ok
      end
    end
  end
end
