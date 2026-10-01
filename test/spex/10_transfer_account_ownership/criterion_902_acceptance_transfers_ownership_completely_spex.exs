defmodule MetricFlowSpex.Criterion902AcceptanceTransfersOwnershipCompletelySpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 902 — Acceptance transfers ownership completely.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Acceptance transfers ownership completely", criterion: 902 do
    scenario "the new owner has authenticated and confirmed acceptance" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the new owner has authenticated and the transfer is pending", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id),
          "remain_admin" => "false"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/account_transfers/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :transfer_token, token)}
      end

      when_ "the transfer completes", context do
        {:ok, view, _html} = live(context.member_conn, "/account_transfers/#{context.transfer_token}")

        view
        |> element("[data-role='accept-transfer-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "ownership of the account transfers completely to the new owner", context do
        {:ok, view, _html} = live(context.member_conn, "/app/accounts/settings")
        assert has_element?(view, "[data-role='transfer-ownership']")
        assert has_element?(view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
