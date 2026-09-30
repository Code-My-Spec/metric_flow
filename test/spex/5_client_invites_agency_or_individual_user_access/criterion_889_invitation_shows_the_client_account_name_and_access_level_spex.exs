defmodule MetricFlowSpex.Criterion889InvitationShowsTheClientAccountNameAndAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation shows the client account name and access level", criterion: 889 do
    scenario "the invitee views an invitation sent with a chosen access level" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a client sends an invitation with a chosen access level", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: context.second_user_email,
            role: "admin"
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

      when_ "the invitee views the invitation", context do
        {:ok, view, _html} = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows the client account's name and the access level being granted", context do
        html = render(context.view)
        assert html =~ "Owner Account"
        assert html =~ "Admin"
        {:ok, context}
      end
    end
  end
end
