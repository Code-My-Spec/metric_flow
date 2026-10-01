defmodule MetricFlowSpex.Criterion898TransferCompletesOnlyAfterEmailConfirmationSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 898 — A transfer completes only after email confirmation.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Transfer completes only after email confirmation", criterion: 898 do
    scenario "the new owner has not yet confirmed via email" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "a transfer invitation has been sent", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id)
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the new owner has not yet confirmed via email", context do
        {:ok, context}
      end

      then_ "the transfer remains pending and does not complete", context do
        {:ok, view, _html} = live(context.member_conn, "/app/accounts/settings")
        refute has_element?(view, "[data-role='transfer-ownership']")
        {:ok, context}
      end
    end
  end
end
