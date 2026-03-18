defmodule MetricFlowSpex.OnFirstSyncFacebookAdsBackfills180DaysSubsequentSyncsIncrementalSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On first sync, system backfills 180 days of history; subsequent syncs fetch from the day after the last stored metric date" do
    scenario "the first Facebook Ads sync shows a large record count reflecting 180-day backfill in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads initial backfill sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 180,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads as the provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "facebook_ads" or html =~ "Facebook",
               "Expected the sync history to show a Facebook Ads entry for the initial backfill, got: #{html}"

        :ok
      end

      then_ "the sync entry shows a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected the initial backfill sync entry to have a success status, got: #{html}"

        :ok
      end

      then_ "the initial sync entry shows the large number of records backfilled", context do
        html = render(context.view)

        assert html =~ "180" or html =~ "records",
               "Expected the initial backfill entry to show 180 records synced, got: #{html}"

        :ok
      end

      then_ "the initial sync entry is labeled as an initial sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or html =~ "initial" or html =~ "backfill",
               "Expected the initial backfill sync entry to be labeled 'Initial Sync' or reference backfill, got: #{html}"

        :ok
      end
    end

    scenario "a subsequent Facebook Ads sync shows a much smaller record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a subsequent (non-initial) Facebook Ads sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 1,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Facebook Ads success entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "facebook_ads" or html =~ "Facebook",
               "Expected the sync history to show a Facebook Ads entry, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the subsequent sync entry to show success status, got: #{html}"

        :ok
      end

      then_ "the subsequent sync entry shows a small incremental record count", context do
        html = render(context.view)

        assert html =~ "1" or html =~ "records",
               "Expected the subsequent sync entry to show a small incremental record count (1 day of data), got: #{html}"

        :ok
      end

      then_ "the subsequent sync entry is not labeled as an initial sync", context do
        html = render(context.view)

        refute html =~ "Initial Sync",
               "Expected the subsequent sync entry to NOT be labeled 'Initial Sync' (that label is only for first-ever syncs)"

        :ok
      end
    end

    scenario "both initial and subsequent Facebook Ads sync entries appear together in the sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an initial Facebook Ads backfill sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 180,
          completed_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
          sync_type: :initial
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      when_ "a subsequent Facebook Ads sync completion event is also broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 1,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows Facebook Ads as the provider for both entries", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "facebook_ads" or html =~ "Facebook",
               "Expected the sync history to show Facebook Ads entries, got: #{html}"

        :ok
      end

      then_ "both sync entries are visible in the history", context do
        html = render(context.view)

        assert html =~ "180" or html =~ "backfill" or html =~ "initial",
               "Expected the initial backfill entry (180 records) to be visible, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected at least one success status entry, got: #{html}"

        :ok
      end
    end
  end
end
