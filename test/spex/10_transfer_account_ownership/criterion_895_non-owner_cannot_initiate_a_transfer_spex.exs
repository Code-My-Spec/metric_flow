defmodule MetricFlowSpex.Criterion895NonOwnerCannotInitiateATransferSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 895 — A non-owner cannot initiate an ownership transfer.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Non-owner cannot initiate a transfer", criterion: 895 do
    scenario "a member who is not the current account owner attempts to transfer ownership" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      when_ "they attempt to initiate an ownership transfer", context do
        owner = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        {:ok, view, _html} = live(context.member_conn, "/app/accounts/settings")

        render_hook(view, "transfer_ownership", %{"user_id" => to_string(owner.id)})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "they are blocked from doing so", context do
        assert render(context.view) =~ "not authorized"
        {:ok, context}
      end
    end
  end
end
