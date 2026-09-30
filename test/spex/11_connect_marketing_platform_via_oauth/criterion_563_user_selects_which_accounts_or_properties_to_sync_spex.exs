defmodule MetricFlowSpex.UserSelectsWhichAccountsOrPropertiesToSyncSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects which accounts or properties to sync", criterion: 563 do
    scenario "Dana is shown her available Google Ads accounts and can select which to sync" do
      given_ :owner_with_google_ads_integration

      when_ "Dana is shown her available ad accounts", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "she can select which accounts to sync", context do
        assert has_element?(context.view, "input[type='radio'][data-role='account-checkbox']") or
                 has_element?(context.view, "[data-role='manual-property-input']")
        {:ok, context}
      end
    end
  end
end
