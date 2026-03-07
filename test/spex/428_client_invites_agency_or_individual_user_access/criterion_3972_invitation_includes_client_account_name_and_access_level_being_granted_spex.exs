defmodule MetricFlowSpex.InvitationIncludesClientAccountNameAndAccessLevelBeingGrantedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "Invitation includes client account name and access level being granted" do
    scenario "invitation email subject contains the account name" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends an invitation with a specified role", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email subject contains the account name", context do
        assert_email_sent(fn email ->
          assert email.subject =~ "Owner Account"
        end)

        :ok
      end
    end

    scenario "invitation email body contains the account name" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends an invitation", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email body contains the account name so the invitee knows which account they are joining", context do
        assert_email_sent(fn email ->
          assert email.text_body =~ "Owner Account"
        end)

        :ok
      end
    end

    scenario "invitation acceptance page shows the account name and granted role to the invitee" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner submits the invite form for admin access", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the invitation token is captured from the sent email", context do
        token =
          assert_email_sent(fn email ->
            assert email.text_body =~ "/invitations/"
            [_, token] = Regex.run(~r|/invitations/([^\s]+)|, email.text_body)
            token
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
            remember_me: false
          })

        logged_in_conn = submit_form(login_form, login_conn)
        invitee_conn = recycle(logged_in_conn)
        {:ok, Map.put(context, :invitee_conn, invitee_conn)}
      end

      when_ "the invitee visits the invitation acceptance page", context do
        {:ok, view, _html} = live(context.invitee_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :accept_view, view)}
      end

      then_ "the acceptance page shows the account name", context do
        assert render(context.accept_view) =~ "Owner Account"
        :ok
      end

      then_ "the acceptance page shows the access level being granted", context do
        assert render(context.accept_view) =~ "Admin"
        :ok
      end
    end
  end
end
