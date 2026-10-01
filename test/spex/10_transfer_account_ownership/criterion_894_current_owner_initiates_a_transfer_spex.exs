defmodule MetricFlowSpex.Criterion894CurrentOwnerInitiatesATransferSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 894 — The current owner can initiate an ownership transfer.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Current owner initiates a transfer", criterion: 894 do
    scenario "the owner is the current account owner and initiates a transfer" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      when_ "they initiate an ownership transfer to the existing member", context do
        member = MetricFlowTest.UsersFixtures.get_user_by_email(context.member_email)
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#transfer-ownership-form", %{
          "transfer_target" => "existing",
          "user_id" => to_string(member.id)
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the transfer process begins", context do
        assert has_element?(context.view, "[data-role='transfer-pending-banner']")
        {:ok, context}
      end
    end
  end
end
