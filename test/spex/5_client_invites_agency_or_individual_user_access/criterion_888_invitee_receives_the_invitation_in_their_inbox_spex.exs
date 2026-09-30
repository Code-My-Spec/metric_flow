defmodule MetricFlowSpex.Criterion888InviteeReceivesTheInvitationInTheirInboxSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitee receives the invitation in their inbox", criterion: 888 do
    scenario "delivery of an invitation places it in the invitee's inbox" do
      given_ :user_logged_in_as_owner

      given_ "a client has sent an invitation to an email address", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "inbox-delivery@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      when_ "delivery completes", context do
        {:ok, context}
      end

      then_ "the invitee finds the invitation in their email inbox", context do
        assert_email_sent(to: "inbox-delivery@example.com")
        {:ok, context}
      end
    end
  end
end
