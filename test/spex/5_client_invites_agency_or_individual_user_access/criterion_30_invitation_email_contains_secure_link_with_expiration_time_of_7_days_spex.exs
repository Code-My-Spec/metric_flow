defmodule MetricFlowSpex.Criterion30InvitationEmailContainsSecureLinkWithExpirationTimeOf7DaysSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation email contains secure link with expiration time of 7 days", criterion: 30 do
    scenario "the invitation email links to a secure invitation page and expires in 7 days" do
      given_(:user_logged_in_as_owner)

      when_ "the owner sends an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "expiry-check@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the email contains a secure link to accept the invitation", context do
        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            token
          end)

        assert byte_size(token) > 10
        {:ok, Map.put(context, :token, token)}
      end

      then_ "the pending invitation shows an expiration date 7 days from now", context do
        expected_expiry =
          Calendar.strftime(DateTime.add(DateTime.utc_now(), 7, :day), "%b %d, %Y")

        assert render(context.view) =~ expected_expiry
        {:ok, context}
      end
    end
  end
end
