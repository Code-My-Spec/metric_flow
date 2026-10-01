defmodule MetricFlowSpex.Criterion71UponAcceptanceOwnershipTransfersCompletelyToNewOwnerSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 71 — Upon acceptance, ownership transfers completely to the new owner.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Upon acceptance, ownership transfers completely to new owner", criterion: 71 do
    scenario "the member accepts an ownership transfer" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the owner has initiated a transfer to the member, not remaining as admin", context do
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

      when_ "the member confirms the transfer", context do
        {:ok, view, _html} = live(context.member_conn, "/account_transfers/#{context.transfer_token}")

        view
        |> element("[data-role='accept-transfer-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the new owner has full ownership of the account", context do
        {:ok, view, _html} = live(context.member_conn, "/app/accounts/settings")
        assert has_element?(view, "[data-role='transfer-ownership']")
        assert has_element?(view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
