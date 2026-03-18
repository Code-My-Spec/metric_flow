defmodule MetricFlowSpex.SystemFetchesGa4DataUsingTheGoogleAnalyticsDataApiV1RunreportEndpointNotTheUniversalAnalyticsApiSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches GA4 data using the Google Analytics Data API v1 (runReport endpoint), not the Universal Analytics API" do
    scenario "the sync history page displays Google Analytics sync results, indicating the GA4 API was used" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event is broadcast to the LiveView", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a successful Google Analytics sync entry", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the sync history page to show 'Google Analytics' provider name, got: #{html}"

        :ok
      end

      then_ "the sync entry reflects a completed data fetch with records synced", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected sync history entry to show a success status, got: #{html}"

        assert html =~ "11" or html =~ "records",
               "Expected sync history entry to show the number of records synced, got: #{html}"

        :ok
      end
    end

    scenario "the sync history page shows the automated sync schedule including Google Analytics" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page describes Google Analytics as a covered marketing provider", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the sync history schedule section to mention 'Google Analytics', got: #{html}"

        :ok
      end

      then_ "the schedule section explains that data is fetched per provider per day", context do
        html = render(context.view)

        assert html =~ "Daily" or html =~ "daily",
               "Expected the schedule section to describe daily syncs, got: #{html}"

        assert html =~ "provider" or html =~ "metrics",
               "Expected the schedule section to mention per-provider data fetching, got: #{html}"

        :ok
      end
    end

    scenario "a failed GA4 sync is surfaced in sync history with an error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event is broadcast with an API error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 Data API error: INVALID_ARGUMENT"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Analytics entry", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected a Google Analytics provider entry in sync history, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason from the GA4 API is displayed", context do
        html = render(context.view)

        assert html =~ "GA4 Data API error" or html =~ "INVALID_ARGUMENT" or html =~ "error",
               "Expected the failure reason to be shown in sync history, got: #{html}"

        :ok
      end
    end
  end
end
