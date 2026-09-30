defmodule MetricFlowSpex.AdminSeesSyncNowButtonInIntegrationSettingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Admin sees Sync Now button in integration settings", criterion: 580 do
    scenario "admin with admin access to the account sees a Sync Now button on an integration" do
      given_ :owner_with_integrations

      when_ "they open an integration's settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see a Sync Now button", context do
        assert has_element?(context.view, "button", "Sync Now")
        {:ok, context}
      end
    end
  end
end
