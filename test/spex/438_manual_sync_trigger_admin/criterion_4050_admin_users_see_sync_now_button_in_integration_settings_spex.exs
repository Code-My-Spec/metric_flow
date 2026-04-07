defmodule MetricFlowSpex.AdminUsersSeesSyncNowButtonInIntegrationSettingsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Admin users see Sync Now button in integration settings" do
    scenario "connected integration shows a Sync Now button" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the connected integration card shows a Sync Now button", context do
        assert has_element?(context.view, "button", "Sync Now")
        :ok
      end
    end

    scenario "available (not connected) integration does NOT show a Sync Now button" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the available platform card does not contain a Sync Now button", context do
        refute has_element?(
          context.view,
          "[data-role='integration-card'][data-status='available'] button",
          "Sync Now"
        )
        :ok
      end
    end

    scenario "the Sync Now button is clickable (not disabled) when no sync is in progress" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Sync Now button is enabled and not disabled", context do
        # Verify a non-disabled Sync Now button exists for the connected integration
        refute has_element?(context.view, "button[disabled]", "Sync Now")
        assert has_element?(context.view, "button", "Sync Now")
        :ok
      end
    end
  end
end
