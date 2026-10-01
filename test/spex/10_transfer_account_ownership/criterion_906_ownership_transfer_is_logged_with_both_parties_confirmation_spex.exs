defmodule MetricFlowSpex.Criterion906OwnershipTransferIsLoggedWithBothPartiesConfirmationSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 906 — Ownership transfer is logged with both parties' confirmation.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Ownership transfer is logged with both parties' confirmation", criterion: 906 do
    scenario "an ownership transfer has completed" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "an ownership transfer has completed", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id)
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/account_transfers/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, accept_view, _html} = live(context.member_conn, "/account_transfers/#{token}")

        accept_view
        |> element("[data-role='accept-transfer-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "the system records the event", context do
        {:ok, context}
      end

      then_ "it logs the transfer along with confirmation from both the previous and new owner", context do
        {:ok, view, _html} = live(context.member_conn, "/app/accounts/settings")
        html = render(view)
        assert html =~ context.owner_email
        assert html =~ context.member_email
        assert has_element?(view, "[data-role='ownership-transfer-log-entry']")
        {:ok, context}
      end
    end
  end
end
