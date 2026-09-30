defmodule MetricFlowSpex.Criterion887InvitationEmailContainsASecureLinkThatExpiresIn7DaysSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Invitation email contains a secure link that expires in 7 days", criterion: 887 do
    scenario "the invitee receives an email with a secure link that expires 7 days from when it was sent" do
      given_ :user_logged_in_as_owner

      given_ "a client sends an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "secure-link@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the invitee receives the email", context do
        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            token
          end)

        {:ok, Map.put(context, :token, token)}
      end

      then_ "it contains a secure link that expires 7 days from when it was sent", context do
        assert byte_size(context.token) > 10

        expected_expiry = Calendar.strftime(DateTime.add(DateTime.utc_now(), 7, :day), "%b %d, %Y")
        assert render(context.view) =~ expected_expiry
        {:ok, context}
      end
    end
  end
end
