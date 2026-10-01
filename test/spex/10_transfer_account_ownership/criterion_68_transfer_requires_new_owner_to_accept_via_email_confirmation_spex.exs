defmodule MetricFlowSpex.Criterion68TransferRequiresNewOwnerToAcceptViaEmailConfirmationSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 68 — A transfer requires the new owner to accept via email confirmation.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Transfer requires new owner to accept via email confirmation", criterion: 68 do
    scenario "ownership does not change until the new owner confirms" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      when_ "the owner initiates a transfer to the existing member", context do
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

      then_ "the previous owner still has owner-level access until the new owner confirms", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        assert has_element?(view, "[data-role='transfer-ownership']")
        {:ok, context}
      end
    end
  end
end
