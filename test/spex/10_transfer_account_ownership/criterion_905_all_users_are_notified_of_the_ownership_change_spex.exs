defmodule MetricFlowSpex.Criterion905AllUsersAreNotifiedOfTheOwnershipChangeSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 905 — All users are notified of the ownership change.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "All users are notified of the ownership change", criterion: 905 do
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

      when_ "the change takes effect", context do
        {:ok, context}
      end

      then_ "all users with access to the account are notified of the ownership change", context do
        assert_email_sent(to: context.owner_email)
        assert_email_sent(to: context.member_email)
        {:ok, context}
      end
    end
  end
end
