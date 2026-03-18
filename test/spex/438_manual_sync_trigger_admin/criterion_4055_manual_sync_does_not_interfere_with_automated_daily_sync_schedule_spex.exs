defmodule MetricFlowSpex.ManualSyncDoesNotInterfereWithAutomatedDailySyncScheduleSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Manual sync does not interfere with automated daily sync schedule" do
    scenario "after a manual sync completes, the integration still shows Connected status" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page with a connected Google integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user triggers a manual sync for the Google integration", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      when_ "the manual sync completes successfully", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        }})

        # Allow the LiveView to process the completion message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the integration still shows the Connected badge indicating automated syncing remains active", context do
        html = render(context.view)

        assert html =~ "Connected",
               "Expected the integration to still show 'Connected' status after manual sync, got: #{html}"

        :ok
      end

      then_ "the connected integration does not show an error or disconnected state", context do
        # Check the connected Google integration card specifically — not the whole page,
        # since available platforms legitimately show "Not connected".
        refute has_element?(
          context.view,
          "[data-role='integration-card'][data-platform='google_analytics'] [data-status='disconnected']"
        ),
        "Expected the connected Google Analytics integration NOT to show a disconnected status after manual sync"

        assert has_element?(
          context.view,
          "[data-role='integration-card'][data-platform='google_analytics'] [data-status='connected']"
        ),
        "Expected the connected Google Analytics integration to still show 'Connected' status"

        :ok
      end
    end

    scenario "after a manual sync completes, the Sync Now button is available again for future syncs" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page with a connected Google integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user triggers a manual sync for the Google integration", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      then_ "the Sync Now button is temporarily disabled while the manual sync is in progress", context do
        assert has_element?(
          context.view,
          "[data-platform='google_analytics'] button[phx-click='sync'][disabled]",
          "Sync Now"
        ),
        "Expected the Sync Now button to be disabled while sync is in progress"

        :ok
      end

      when_ "the manual sync completes successfully", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        }})

        # Allow the LiveView to process the completion message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the Sync Now button is re-enabled so future manual and automated syncs can coexist", context do
        refute has_element?(
          context.view,
          "[data-platform='google_analytics'] button[phx-click='sync'][disabled]"
        ),
        "Expected the Sync Now button to be re-enabled after manual sync completed, but it was still disabled"

        :ok
      end

      then_ "the Sync Now button is present and available for the user to trigger another sync", context do
        assert has_element?(
          context.view,
          "button[phx-click='sync']",
          "Sync Now"
        ),
        "Expected the Sync Now button to still be present on the page after sync completed"

        :ok
      end
    end
  end
end
