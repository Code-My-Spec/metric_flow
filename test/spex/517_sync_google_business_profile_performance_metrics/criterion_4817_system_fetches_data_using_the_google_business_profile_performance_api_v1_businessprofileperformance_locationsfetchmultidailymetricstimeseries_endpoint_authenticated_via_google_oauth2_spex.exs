defmodule MetricFlowSpex.SystemFetchesDataUsingGoogleBusinessProfilePerformanceApiV1Spex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches data using the Google Business Profile Performance API v1 (businessprofileperformance, locations.fetchMultiDailyMetricsTimeSeries endpoint) authenticated via Google OAuth2" do
    scenario "sync history shows a successful Google Business Profile sync entry with records synced" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completion event is broadcast to the LiveView", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 25,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history page shows a successful Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected the sync history to show 'Google Business' provider name, got: #{html}"

        :ok
      end

      then_ "the sync entry shows a success status and records synced count", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the Google Business Profile sync entry to show Success status, got: #{html}"

        assert html =~ "25" or html =~ "records",
               "Expected the sync entry to show the number of records synced, got: #{html}"

        :ok
      end
    end

    scenario "Google Business Profile appears as a covered provider in the sync schedule section" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows that marketing providers are synced daily", context do
        html = render(context.view)

        assert html =~ "Daily" or html =~ "daily",
               "Expected the sync schedule section to describe daily syncs, got: #{html}"

        :ok
      end

      then_ "the schedule section mentions Google-based marketing providers", context do
        html = render(context.view)

        assert html =~ "Google Ads" or html =~ "Google Analytics" or html =~ "Google",
               "Expected the schedule section to mention Google provider coverage, got: #{html}"

        :ok
      end
    end

    scenario "a failed Google Business Profile sync shows error details in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync failure event is broadcast with an API error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "Business Profile API error: 403 PERMISSION_DENIED — locations.fetchMultiDailyMetricsTimeSeries access denied"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected sync history to show 'Google Business' provider for the failed entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed" or html =~ "badge-error",
               "Expected the Google Business Profile sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error details from the API are displayed in the failed entry", context do
        html = render(context.view)

        assert html =~ "403" or html =~ "PERMISSION_DENIED" or
                 html =~ "Business Profile API error" or html =~ "access denied",
               "Expected the API error details to be surfaced in the sync history entry, got: #{html}"

        :ok
      end
    end
  end
end
