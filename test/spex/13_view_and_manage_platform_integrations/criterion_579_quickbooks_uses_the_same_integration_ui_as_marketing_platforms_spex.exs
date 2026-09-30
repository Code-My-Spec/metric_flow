defmodule MetricFlowSpex.QuickbooksUsesTheSameIntegrationUiAsMarketingPlatformsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "QuickBooks uses the same integration UI as marketing platforms", criterion: 579 do
    scenario "a connected QuickBooks integration and a connected marketing platform integration" do
      given_ :owner_with_quickbooks_integration

      given_ "the user also has a connected marketing platform integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{provider: :google_ads})
        {:ok, context}
      end

      when_ "the user views and manages each", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both are presented and managed through the identical uniform UI", context do
        assert has_element?(
                 context.view,
                 "[data-platform='quickbooks'] [data-role='disconnect-integration']"
               )

        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='disconnect-integration']"
               )

        assert has_element?(
                 context.view,
                 "[data-platform='quickbooks'] [data-role='integration-sync-status']"
               )

        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='integration-sync-status']"
               )

        {:ok, context}
      end
    end
  end
end
