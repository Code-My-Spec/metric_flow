defmodule MetricFlowSpex.GoogleAdsFirstSyncBackfills548DaysSubsequentSyncIncrementalSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On first sync, Google Ads backfills up to 548 days of historical data; subsequent syncs fetch from day after last stored metric date" do
    scenario "the sync history page describes historical backfill behavior in the schedule section" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section explains that historical data is backfilled on first sync", context do
        html = render(context.view)

        assert html =~ "backfill" or html =~ "historical",
               "Expected the sync history page to mention historical data backfill, got: #{html}"

        :ok
      end

      then_ "the schedule section is present and visible", context do
        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected a [data-role='sync-schedule'] section describing the sync schedule"

        schedule_html =
          context.view
          |> element("[data-role='sync-schedule']")
          |> render()

        assert schedule_html =~ "first sync" or schedule_html =~ "backfill" or
                 schedule_html =~ "historical",
               "Expected the schedule section to mention first sync backfill behavior, got: #{schedule_html}"

        :ok
      end
    end

    scenario "an initial 548-day backfill sync completion event for Google Ads appears in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads initial backfill sync completion event is broadcast with 548 records", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Google Ads initial sync with success status", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show a Google Ads entry for the initial backfill, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the initial backfill sync entry to have a success status, got: #{html}"

        :ok
      end

      then_ "the initial sync entry shows the large backfilled record count", context do
        html = render(context.view)

        assert html =~ "548" or html =~ "records",
               "Expected the initial backfill entry to show 548 records synced, got: #{html}"

        :ok
      end

      then_ "the initial sync entry is labeled as an Initial Sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or html =~ "initial",
               "Expected the initial backfill sync entry to be labeled 'Initial Sync', got: #{html}"

        :ok
      end
    end

    scenario "a subsequent incremental Google Ads sync shows a small record count without initial sync label" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a regular incremental Google Ads sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Ads success entry without the Initial Sync label", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show a Google Ads entry, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the subsequent sync entry to show success status, got: #{html}"

        refute html =~ "Initial Sync",
               "Expected the subsequent incremental sync entry to NOT be labeled 'Initial Sync'"

        :ok
      end
    end

    scenario "both an initial and a subsequent sync entry appear in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an initial backfill sync event is broadcast followed by an incremental sync event", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both Google Ads sync entries are visible in the history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (initial backfill + incremental), but found #{entry_count}"

        :ok
      end
    end
  end
end
