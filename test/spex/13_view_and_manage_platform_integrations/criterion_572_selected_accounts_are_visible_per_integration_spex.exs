defmodule MetricFlowSpex.SelectedAccountsAreVisiblePerIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Selected accounts are visible per integration", criterion: 572 do
    scenario "a connected integration with accounts selected" do
      given_ :owner_with_integrations

      given_ "the user views that integration's details", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees which accounts or properties are currently selected", context do
        assert has_element?(context.view, "[data-role='integration-selected-accounts']")
        {:ok, context}
      end
    end
  end
end
