defmodule MetricFlowSpex.AccountOriginatorCannotSelfRevokeAndMustTransferOwnershipFirstSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Account originator cannot self-revoke and must transfer ownership first", criterion: 65 do
    scenario "the originator sees transfer ownership instead of a self-revoke option" do
      given_ :user_logged_in_as_owner

      given_ "the originator navigates to account settings", context do
        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      then_ "no self-revoke option is offered to the originator", context do
        refute has_element?(context.settings_view, "[data-role='revoke-own-access']")
        {:ok, context}
      end

      then_ "the originator is offered ownership transfer instead", context do
        assert has_element?(context.settings_view, "[data-role='transfer-ownership']")
        {:ok, context}
      end
    end
  end
end
