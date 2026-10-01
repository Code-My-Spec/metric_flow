defmodule MetricFlowSpex.AccountOriginatorCannotSelfRevokeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Account originator cannot self-revoke", criterion: 912 do
    scenario "the account's originator and owner sees no self-revoke option" do
      given_ :user_logged_in_as_owner

      given_ "the originator navigates to account settings", context do
        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      when_ "they attempt to self-revoke", context do
        {:ok, context}
      end

      then_ "they are blocked and told to transfer ownership first", context do
        refute has_element?(context.settings_view, "[data-role='revoke-own-access']")
        assert has_element?(context.settings_view, "[data-role='transfer-ownership']")
        {:ok, context}
      end
    end
  end
end
