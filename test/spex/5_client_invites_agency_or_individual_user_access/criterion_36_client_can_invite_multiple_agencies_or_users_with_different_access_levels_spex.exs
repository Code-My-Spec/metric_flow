defmodule MetricFlowSpex.Criterion36ClientCanInviteMultipleAgenciesOrUsersWithDifferentAccessLevelsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Client can invite multiple agencies or users with different access levels",
    criterion: 36 do
    scenario "the owner sends two invitations at different access levels and both appear pending" do
      given_ :user_logged_in_as_owner

      given_ "the owner invites one party as account manager", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "agency-one@example.com",
            role: "account_manager"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner invites a second party as read-only", context do
        context.view
        |> form("#invite_member_form",
          invitation: %{
            email: "individual-two@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "both invitations are sent with their own access levels", context do
        assert_email_sent(to: "agency-one@example.com")
        assert_email_sent(to: "individual-two@example.com")

        html = render(context.view)
        assert html =~ "agency-one@example.com"
        assert html =~ "Account Manager"
        assert html =~ "individual-two@example.com"
        assert html =~ "Read Only"
        {:ok, context}
      end
    end
  end
end
