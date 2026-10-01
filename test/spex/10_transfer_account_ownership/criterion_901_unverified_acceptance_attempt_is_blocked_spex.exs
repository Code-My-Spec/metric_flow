defmodule MetricFlowSpex.Criterion901UnverifiedAcceptanceAttemptIsBlockedSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 901 — An unverified acceptance attempt is blocked.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Unverified acceptance attempt is blocked", criterion: 901 do
    scenario "someone attempts to accept a transfer invitation without authenticating" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "a transfer invitation link exists", context do
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

      when_ "someone attempts to accept it without authenticating or verifying identity", context do
        {:ok, view, _html} = live(build_conn(), "/account_transfers/#{context.transfer_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the acceptance is blocked", context do
        refute has_element?(context.view, "[data-role='accept-transfer-btn']")

        {:ok, owner_view, _html} = live(context.owner_conn, "/app/accounts/settings")
        assert has_element?(owner_view, "[data-role='transfer-ownership']")
        {:ok, context}
      end
    end
  end
end
