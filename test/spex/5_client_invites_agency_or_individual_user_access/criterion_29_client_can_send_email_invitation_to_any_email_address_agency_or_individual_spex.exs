defmodule MetricFlowSpex.Criterion29ClientCanSendEmailInvitationToAnyEmailAddressSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Client can send email invitation to any email address (agency or individual)",
    criterion: 29 do
    scenario "a client sends an invitation to an email address that has no existing account" do
      given_ :user_logged_in_as_owner

      when_ "the owner sends an invitation to an arbitrary email address", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "newcomer@anyagency.example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invitation is sent, regardless of whether the address belongs to an agency or an individual", context do
        assert_email_sent(to: "newcomer@anyagency.example.com")
        assert render(context.view) =~ "newcomer@anyagency.example.com"
        {:ok, context}
      end
    end
  end
end
