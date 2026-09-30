defmodule MetricFlowSpex.Criterion893ClientInvitesMultiplePartiesWithDifferentAccessLevelsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Client invites multiple parties with different access levels", criterion: 893 do
    scenario "a client grants different access to an agency and an individual in separate invitations" do
      given_ :user_logged_in_as_owner

      when_ "they send invitations to an agency with account manager access and an individual with read-only access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "the-agency@example.com",
            role: "account_manager"
          }
        )
        |> render_submit()

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "the-individual@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "both invitations are sent with their respective access levels", context do
        assert_email_sent(to: "the-agency@example.com")
        assert_email_sent(to: "the-individual@example.com")

        html = render(context.view)
        assert html =~ "the-agency@example.com"
        assert html =~ "Account Manager"
        assert html =~ "the-individual@example.com"
        assert html =~ "Read Only"
        {:ok, context}
      end
    end
  end
end
