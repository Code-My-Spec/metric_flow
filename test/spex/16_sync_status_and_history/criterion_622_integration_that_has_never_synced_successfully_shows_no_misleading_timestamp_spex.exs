defmodule MetricFlowSpex.IntegrationThatHasNeverSyncedSuccessfullyShowsNoMisleadingTimestampSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integration that has never synced successfully shows no misleading timestamp",
    criterion: 622 do
    scenario "an integration with no successful sync history shows that it has never synced" do
      given_(:user_logged_in_as_owner)

      given_ "an integration has never completed a successful sync", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "the user views that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows that it has never synced rather than a blank or misleading timestamp",
            context do
        html = render(context.view)
        assert html =~ "google_ads" or has_element?(context.view, "[data-platform='google_ads']")

        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='last-sync-at']",
                 "Never synced"
               )

        {:ok, context}
      end
    end
  end
end
