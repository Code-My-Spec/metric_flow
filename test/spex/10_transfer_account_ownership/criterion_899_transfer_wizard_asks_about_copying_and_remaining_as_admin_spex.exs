defmodule MetricFlowSpex.Criterion899TransferWizardAsksAboutCopyingAndRemainingAsAdminSpex do
  @moduledoc """
  Story 10 — Transfer Account Ownership
  Criterion 899 — The transfer wizard asks about copying and remaining as admin.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Transfer wizard asks about copying and remaining as admin", criterion: 899 do
    scenario "the current owner goes through the transfer wizard" do
      given_ :user_logged_in_as_owner

      when_ "they go through the transfer wizard", context do
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
