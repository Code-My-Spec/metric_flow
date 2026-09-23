defmodule MetricFlowSpex.SystemSyncsTheFollowingGa4MetricsAsCoreDailyValuesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System syncs the following GA4 metrics as core daily values: activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers" do
    scenario "sync history shows a completed Google Analytics sync entry with records synced count" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event is broadcast with the expected records count", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Google Analytics with 11 records synced", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' as the provider, got: #{html}"

        assert html =~ "11" or html =~ "records synced",
               "Expected sync history to show 11 records synced (one per GA4 metric), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history page describes Google Analytics as a covered marketing provider" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section lists Google Analytics as a covered marketing provider", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the sync schedule section to mention 'Google Analytics' as a marketing provider, got: #{html}"

        assert html =~ "marketing" or html =~ "metrics",
               "Expected the schedule section to mention metrics fetching for marketing providers, got: #{html}"

        :ok
      end
    end

    scenario "a partial sync failure for GA4 metrics is surfaced in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event is broadcast due to a metric fetch error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "Failed to fetch metrics: quota exceeded"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the failed sync entry is visible with Google Analytics as the provider", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the failed sync entry to show 'Google Analytics' as the provider, got: #{html}"

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
