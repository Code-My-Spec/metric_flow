defmodule MetricFlowSpex.Criterion900NewOwnerVerifiesIdentityBeforeAcceptingSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 900 — The new owner verifies identity before accepting.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "New owner verifies identity before accepting", criterion: 900 do
    scenario "a new owner has received a transfer invitation and goes to accept it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "a new owner has received a transfer invitation", context do
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

        {:ok, Map.put(context, :transfer_token, token)}
      end

      when_ "they go to accept it without being logged in", context do
        {:ok, view, _html} = live(build_conn(), "/account_transfers/#{context.transfer_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they must authenticate or verify their identity first", context do
        assert has_element?(context.view, "[data-role='log-in-to-confirm-btn']")
        refute has_element?(context.view, "[data-role='accept-transfer-btn']")
        {:ok, context}
      end
    end
  end
end
