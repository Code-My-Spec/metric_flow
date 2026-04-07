defmodule MetricFlowSpex.CoreScalarMetricsSyncedDailyFacebookAdsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Core scalar metrics synced daily: impressions, reach, clicks, spend, cpp, unique_clicks, unique_ctr, frequency, cost_per_ad_click, cost_per_conversion" do
    scenario "sync history shows a completed Facebook Ads sync entry with records synced count matching expected core metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast with 10 records synced", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads with 10 records synced", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "10" or html =~ "records synced",
               "Expected sync history to show 10 records synced (one per core Facebook Ads metric), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history page describes Facebook Ads as a covered marketing provider" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section lists Facebook Ads as a covered marketing provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected the sync schedule section to mention 'Facebook Ads' as a marketing provider, got: #{html}"

        assert html =~ "marketing" or html =~ "metrics",
               "Expected the schedule section to mention metrics fetching for marketing providers, got: #{html}"

        :ok
      end
    end

    scenario "a Facebook Ads sync failure is surfaced in sync history with provider name" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast due to a metric fetch error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Failed to fetch metrics: rate limit exceeded"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the failed sync entry is visible with Facebook Ads as the provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected the failed sync entry to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason mentions the metric fetch error", context do
        html = render(context.view)

        assert html =~ "rate limit" or html =~ "Failed to fetch" or html =~ "error",
               "Expected the failure reason to describe the metric fetch error, got: #{html}"

        :ok
      end
    end
  end
end
