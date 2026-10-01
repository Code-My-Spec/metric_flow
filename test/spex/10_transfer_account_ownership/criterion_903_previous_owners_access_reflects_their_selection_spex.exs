defmodule MetricFlowSpex.Criterion903PreviousOwnersAccessReflectsTheirSelectionSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 903 — The previous owner's access reflects their selection.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Previous owner's access reflects their selection", criterion: 903 do
    scenario "the previous owner chose to remain as admin during the transfer wizard" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the previous owner chose to remain as admin during the transfer wizard", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id),
          "remain_admin" => "true"
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

      then_ "the previous owner's access level is set to admin rather than owner", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        html = render(view)
        assert html =~ context.owner_email
        assert html =~ "admin"
        {:ok, context}
      end
    end
  end
end
