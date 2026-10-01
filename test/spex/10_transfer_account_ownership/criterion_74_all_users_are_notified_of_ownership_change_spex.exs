defmodule MetricFlowSpex.Criterion74AllUsersAreNotifiedOfOwnershipChangeSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 74 — All users are notified of an ownership change.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "All users are notified of ownership change", criterion: 74 do
    scenario "an ownership transfer completes" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the owner transfers ownership to the member and the member confirms", context do
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

      when_ "the change takes effect", context do
        {:ok, context}
      end

      then_ "the previous owner is notified of the ownership change", context do
        assert_email_sent(to: context.owner_email)
        {:ok, context}
      end

      then_ "the new owner is also notified of the ownership change", context do
        assert_email_sent(to: context.member_email)
        {:ok, context}
      end
    end
  end
end
