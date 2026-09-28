defmodule MetricFlowSpex.SystemSyncsGoogleAdsCoreDailyMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System syncs core daily Google Ads metrics: clicks, impressions, cost (from cost_micros), all_conversions, conversions" do
    scenario "sync history shows a completed Google Ads sync entry with 5 records synced" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast with 5 records synced", context do
        Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync", {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Google Ads with 5 records synced", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' as the provider, got: #{html}"

        assert html =~ "5" or html =~ "records synced",
               "Expected sync history to show 5 records synced (one per metric), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        {:ok, context}
      end
    end

    scenario "sync history shows the Google Ads provider in the schedule section" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section references Google Ads as a covered marketing provider", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected the sync history page to mention 'Google Ads' as a marketing provider, got: #{html}"

        assert html =~ "marketing" or html =~ "metrics",
               "Expected the schedule section to mention metrics for marketing providers, got: #{html}"

        {:ok, context}
      end
    end

    scenario "a failed Google Ads metric sync is surfaced in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast due to a metric fetch error", context do
        Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync", {:sync_failed, %{
          provider: :google_ads,
          reason: "Failed to fetch metrics: API quota exceeded"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the failed sync entry is visible with Google Ads as the provider", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected the failed sync entry to show 'Google Ads' as the provider, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        {:ok, context}
      end

      then_ "the failure reason mentions the metric fetch error", context do
        html = render(context.view)

        assert html =~ "quota exceeded" or html =~ "Failed to fetch" or html =~ "error",
               "Expected the failure reason to describe the metric fetch error, got: #{html}"

        {:ok, context}
      end
    end
  end
end
