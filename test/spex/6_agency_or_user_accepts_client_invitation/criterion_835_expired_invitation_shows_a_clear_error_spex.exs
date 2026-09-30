defmodule MetricFlowSpex.Criterion835ExpiredInvitationShowsAClearErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Expired invitation shows a clear error", criterion: 835 do
    scenario "opening an expired invitation link shows a clear expiration error" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation that is then expired", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: context.second_user_email,
            role: "read_only"
          }
        )
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        # Backdate the invitation to make it expired (no UI path to do this)
        MetricFlowSpex.Fixtures.expire_invitation!(token)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the invitee opens the expired invitation link", context do
        conn = build_conn()
        result = live(conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "a clear expiration error is shown", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "expired"
        {:ok, context}
      end
    end
  end
end
