defmodule MetricFlowSpex.Criterion31InviteeReceivesInvitationInTheirEmailInboxSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitee receives invitation in their email inbox", criterion: 31 do
    scenario "an invitee receives an email in their inbox after being invited" do
      given_ :user_logged_in_as_owner

      when_ "the owner sends an invitation to the invitee's address", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "invitee-inbox@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the invitee's inbox receives the invitation email", context do
        assert_email_sent(to: "invitee-inbox@example.com")
        {:ok, context}
      end
    end
  end
end
