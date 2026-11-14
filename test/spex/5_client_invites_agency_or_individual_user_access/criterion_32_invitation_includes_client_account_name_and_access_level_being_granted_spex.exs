defmodule MetricFlowSpex.Criterion32InvitationIncludesClientAccountNameAndAccessLevelBeingGrantedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation includes client account name and access level being granted", criterion: 32 do
    scenario "the invitation acceptance page shows the inviting account's name and the granted access level" do
      given_(:user_logged_in_as_owner)
      given_(:second_user_registered)

      given_ "the owner invites the second user as account manager", context do
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
            [_, token] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            token
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the invitee opens the invitation", context do
        {:ok, view, _html} = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows the client account's name", context do
        assert render(context.view) =~ "Owner Account"
        {:ok, context}
      end

      then_ "it shows the access level being granted", context do
        assert render(context.view) =~ "Account Manager"
        {:ok, context}
      end
    end
  end
end
