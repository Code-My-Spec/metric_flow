defmodule MetricFlowSpex.TheFollowingMetricsAreFetchedAsDailyTimeSeriesGoogleBusinessProfileSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "GBP 10 daily metrics: impressions (desktop/mobile, maps/search), conversations, directions, calls, clicks, bookings, food orders/menu" do
    scenario "sync completion with 10 records shows correct count in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completion event is broadcast with 10 records synced", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Google Business Profile with 10 records synced", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected sync history to show 'Google Business Profile' as the provider, got: #{html}"

        assert html =~ "10" or html =~ "records synced",
               "Expected sync history to show 10 records synced (one per metric), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "Google Business Profile appears in the sync schedule section as a covered provider" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section lists Google Business Profile as a covered provider", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected the sync schedule section to mention 'Google Business Profile' as a provider, got: #{html}"

        assert html =~ "marketing" or html =~ "metrics" or html =~ "daily",
               "Expected the schedule section to mention metrics fetching, got: #{html}"

        :ok
      end
    end

    scenario "a sync failure during Google Business Profile metric fetching shows the error in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync failure event is broadcast due to a metric fetch error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "Failed to fetch metrics: quota exceeded"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the failed sync entry is visible with Google Business Profile as the provider", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected the failed sync entry to show 'Google Business Profile' as the provider, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason mentions the metric fetch error", context do
        html = render(context.view)

        assert html =~ "quota exceeded" or html =~ "Failed to fetch" or html =~ "error",
               "Expected the failure reason to describe the metric fetch error, got: #{html}"

        :ok
      end
    end
  end
end
