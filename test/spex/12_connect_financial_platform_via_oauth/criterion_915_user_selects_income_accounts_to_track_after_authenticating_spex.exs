defmodule MetricFlowSpex.UserSelectsIncomeAccountsToTrackAfterAuthenticatingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects income accounts to track after authenticating", criterion: 915 do
    scenario "a successfully authenticated user is shown their available income accounts and can select one" do
      given_ :owner_with_quickbooks_integration

      given_ "the user has successfully authenticated with QuickBooks", context do
        {:ok, context}
      end

      when_ "they are shown their available income accounts", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/quickbooks/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can select which ones to track", context do
        assert has_element?(context.view, "[data-role='account-checkbox']") or
                 has_element?(context.view, "[data-role='manual-property-input']")

        {:ok, context}
      end
    end
  end
end
