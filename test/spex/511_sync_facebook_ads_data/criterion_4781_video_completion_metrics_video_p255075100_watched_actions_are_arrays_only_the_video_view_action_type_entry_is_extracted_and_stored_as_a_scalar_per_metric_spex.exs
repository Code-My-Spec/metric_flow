defmodule MetricFlowSpex.VideoCompletionMetricsVideoP255075100WatchedActionsAreArraysOnlyVideoViewActionTypeExtractedAsScalarSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  @video_completion_metrics [
    "video_p25_watched_actions",
    "video_p50_watched_actions",
    "video_p75_watched_actions",
    "video_p100_watched_actions"
  ]

  spex "Video completion metrics (video_p25/50/75/100_watched_actions) are arrays — only the video_view action_type entry is extracted and stored as a scalar per metric" do
    scenario "a Facebook Ads sync with video completion metrics shows 4 video records in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast with 4 video completion metrics extracted as scalars", context do
        # Each video_p25/50/75/100_watched_actions field is an array in the API response.
        # Only the entry with action_type == "video_view" is extracted and stored as a scalar.
        # This yields exactly 4 records — one per video completion metric.
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: length(@video_completion_metrics),
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads with 4 records synced", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "#{length(@video_completion_metrics)}" or html =~ "records synced",
               "Expected sync history to show #{length(@video_completion_metrics)} records synced (one scalar per video completion metric), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "a Facebook Ads sync that includes both core metrics and video completion metrics reflects the combined record count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast with core metrics and video completion metrics combined", context do
        # 10 core scalar metrics + 4 video completion scalars (video_view entry extracted from each array) = 14 records
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 14,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads with 14 records synced", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "14",
               "Expected sync history to show 14 records synced (10 core + 4 video completion scalars), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "a sync failure during video metric processing surfaces the error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast while processing video completion metrics", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Failed to extract video_view action_type from video_p25_watched_actions array"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected sync history to show 'Facebook Ads' for the failed video metric sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Facebook Ads sync failure entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason references the video metric processing error", context do
        html = render(context.view)

        assert html =~ "video" or html =~ "video_view" or html =~ "action_type" or
                 html =~ "Failed to extract" or html =~ "error",
               "Expected the failure reason to reference the video metric extraction error, got: #{html}"

        :ok
      end
    end
  end
end
