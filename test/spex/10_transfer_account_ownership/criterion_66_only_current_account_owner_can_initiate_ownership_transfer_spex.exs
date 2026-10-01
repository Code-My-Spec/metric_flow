defmodule MetricFlowSpex.Criterion66OnlyCurrentAccountOwnerCanInitiateOwnershipTransferSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 66 — Only the current account owner can initiate an ownership transfer.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Only current account owner can initiate ownership transfer", criterion: 66 do
    scenario "a non-owner member does not see a way to initiate an ownership transfer" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      when_ "the member views the account settings page", context do
        {:ok, view, _html} = live(context.member_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no ownership transfer control is available to them", context do
        refute has_element?(context.view, "[data-role='transfer-ownership']")
        {:ok, context}
      end
    end
  end
end
