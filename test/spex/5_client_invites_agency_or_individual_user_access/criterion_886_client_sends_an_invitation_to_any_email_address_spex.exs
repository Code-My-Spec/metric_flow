defmodule MetricFlowSpex.Criterion886ClientSendsAnInvitationToAnyEmailAddressSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Client sends an invitation to any email address", criterion: 886 do
    scenario "a client account owner sends an invitation to an arbitrary email address" do
      given_ :user_logged_in_as_owner

      when_ "they send an invitation to an email address, whether it belongs to an agency or an individual", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "whoever@anydomain.example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invitation is sent to that address", context do
        assert_email_sent(to: "whoever@anydomain.example.com")
        assert render(context.view) =~ "whoever@anydomain.example.com"
        {:ok, context}
      end
    end
  end
end
