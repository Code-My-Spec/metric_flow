defmodule MetricFlowSpex.InvitationLinkIsSingleUseAndInvalidatedAfterAcceptanceOrExpirationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions
  import Ecto.Query

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlow.Invitations
  alias MetricFlow.Repo

  spex "Invitation link is single-use and invalidated after acceptance or expiration" do
    scenario "invitation link cannot be used a second time after it has been accepted" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation to the second user", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the invitation token is captured from the sent email", context do
        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s]+)|, email.text_body)
            token
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
            remember_me: false
          })

        logged_in_conn = submit_form(login_form, login_conn)
        invitee_conn = recycle(logged_in_conn)

        {:ok, accept_view, _html} = live(invitee_conn, "/invitations/#{context.invitation_token}")
        accept_view |> element("[data-role='accept-btn']") |> render_click()

        {:ok, Map.put(context, :invitee_conn, invitee_conn)}
      end

      when_ "the invitee tries to visit the same invitation link again", context do
        fresh_conn = recycle(context.invitee_conn)
        result = live(fresh_conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :second_visit_result, result)}
      end

      then_ "the invitation link is no longer valid", context do
        assert {:error, {:redirect, %{flash: flash}}} = context.second_visit_result
        assert flash["error"] =~ "invalid or has already been used"
        :ok
      end
    end

    scenario "visiting an expired invitation link shows an error to the user" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation to the second user", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the invitation token is captured and then backdated to be expired", context do
        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s]+)|, email.text_body)
            token
          end)

        token_hash = MetricFlow.Invitations.Invitation.token_hash(token)

        Repo.update_all(
          from(i in Invitations.Invitation, where: i.token_hash == ^token_hash),
          set: [inserted_at: ~N[2000-01-01 00:00:00]]
        )

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the invitee tries to visit the expired invitation link", context do
        result = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :visit_result, result)}
      end

      then_ "the user sees an error message explaining the invitation has expired", context do
        assert {:error, {:redirect, %{flash: flash}}} = context.visit_result
        assert flash["error"] =~ "expired"
        :ok
      end
    end

    scenario "a valid pending invitation link can be visited and shows the accept page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation to the second user", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the invitation token is captured from the sent email", context do
        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s]+)|, email.text_body)
            token
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the invitee visits the invitation link", context do
        {:ok, view, _html} = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :accept_view, view)}
      end

      then_ "the acceptance page is displayed confirming the invitation is still valid", context do
        assert render(context.accept_view) =~ "invited"
        :ok
      end
    end
  end
end
