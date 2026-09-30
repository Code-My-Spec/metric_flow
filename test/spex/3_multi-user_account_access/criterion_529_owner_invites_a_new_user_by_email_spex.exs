defmodule MetricFlowSpex.OwnerInvitesANewUserByEmailSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Owner invites a new user by email", criterion: 529 do
    scenario "Alex invites a teammate by email and an invitation is sent" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "Alex is on the invitations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex invites a teammate by email", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "an invitation is sent to that email address", context do
        assert_email_sent(to: context.second_user_email)
        {:ok, context}
      end
    end
  end
end
