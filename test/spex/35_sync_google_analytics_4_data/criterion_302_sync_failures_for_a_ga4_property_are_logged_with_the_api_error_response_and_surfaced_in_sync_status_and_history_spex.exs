defmodule MetricFlowSpex.SyncFailuresForAGa4PropertyAreLoggedAndSurfacedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync failures for a GA4 property are logged with the API error response and surfaced in Sync Status and History",
    fail_on_error_logs: false,
    criterion: 302 do
    scenario "a GA4 sync failure shows the API error in sync history" do
      given_(:user_logged_in_as_owner)

      given_ "a GA4 integration exists with no property configured, which the API rejects",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics)
        {:ok, context}
      end

      when_ "the sync runs and fails", context do
        # The daily Google sync skips a product with nothing selected;
        # syncing the product itself surfaces why it can't sync.
        {:ok, dashboard, _html} =
          live(context.owner_conn, "/app/integrations/google_analytics/dashboard")

        dashboard |> element("[data-role='sync-now']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history shows a failed Google Analytics entry with the API error message",
            context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Google Analytics"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
