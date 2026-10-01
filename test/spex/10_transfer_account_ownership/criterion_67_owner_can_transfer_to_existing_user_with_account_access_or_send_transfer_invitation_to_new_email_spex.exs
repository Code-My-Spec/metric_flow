defmodule MetricFlowSpex.Criterion67OwnerCanTransferToExistingUserWithAccountAccessOrSendTransferInvitationToNewEmailSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 67 — The owner can transfer to an existing user with account access,
  or send a transfer invitation to a new email.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner can transfer to existing user with account access or send transfer invitation to new email",
       criterion: 67 do
    scenario "the owner is offered both an existing member and a new email as transfer targets" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      when_ "they open the transfer ownership section", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can choose an existing member with access", context do
        assert has_element?(context.view, "[data-role='transfer-target-existing-radio']")
        {:ok, context}
      end

      then_ "they can instead send a transfer invitation to a new email", context do
        assert has_element?(context.view, "[data-role='transfer-target-invite-radio']")
        {:ok, context}
      end
    end
  end
end
