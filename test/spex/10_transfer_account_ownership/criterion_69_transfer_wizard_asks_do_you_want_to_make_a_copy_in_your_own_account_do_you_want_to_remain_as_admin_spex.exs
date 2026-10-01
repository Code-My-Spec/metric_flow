defmodule MetricFlowSpex.Criterion69TransferWizardAsksDoYouWantToMakeACopyInYourOwnAccountDoYouWantToRemainAsAdminSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 69 — The transfer wizard asks whether to make a copy in the owner's
  own account, and whether they want to remain as admin after transfer.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Transfer wizard asks: Do you want to make a copy in your own account, Do you want to remain as admin after transfer",
       criterion: 69 do
    scenario "the owner views the transfer ownership wizard" do
      given_ :user_logged_in_as_owner

      when_ "they open the transfer ownership section", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it asks whether to make a copy in their own account", context do
        assert has_element?(context.view, "[data-role='transfer-make-copy-checkbox']")
        {:ok, context}
      end

      then_ "it asks whether they want to remain as admin after transfer", context do
        assert has_element?(context.view, "[data-role='transfer-remain-admin-checkbox']")
        {:ok, context}
      end
    end
  end
end
