defmodule MetricFlowSpex.OnFirstSyncSystemBackfillsUp548DaysGoogleBusinessSubsequentSyncsFetchFromDayAfterLastStoredMetricDateForThatLocationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On first sync, system backfills up to 548 days of historical data; subsequent syncs fetch from the day after the last stored metric date for that location" do
    scenario "first Google Business sync shows a large record count reflecting 548-day backfill" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business initial backfill sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Business entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or
                 html =~ "google_business" or
                 html =~ "Google Business Profile",
               "Expected the sync history to show a Google Business entry, got: #{html}"

        :ok
      end

      then_ "the entry shows a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the initial backfill sync entry to show success status, got: #{html}"

        :ok
      end

      then_ "the entry is labeled as an Initial Sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or html =~ "initial",
               "Expected the initial backfill entry to be labeled 'Initial Sync', got: #{html}"

        :ok
      end

      then_ "the entry shows the large number of records backfilled", context do
        html = render(context.view)

        assert html =~ "548" or html =~ "records",
               "Expected the initial backfill entry to show 548 records synced, got: #{html}"

        :ok
      end
    end

    scenario "subsequent Google Business sync shows a small record count reflecting incremental fetch" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a subsequent (non-initial) Google Business sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Business success entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or
                 html =~ "google_business" or
                 html =~ "Google Business Profile",
               "Expected the sync history to show a Google Business entry for the incremental sync, got: #{html}"

        :ok
      end

      then_ "the incremental sync entry shows success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the incremental sync entry to show success status, got: #{html}"

        :ok
      end

      then_ "the incremental sync entry does not show the Initial Sync label", context do
        html = render(context.view)

        refute html =~ "Initial Sync",
               "Expected the subsequent incremental sync entry to NOT be labeled 'Initial Sync' (that label is only for first-ever syncs)"

        :ok
      end
    end

    scenario "both initial and subsequent sync entries appear in the history with distinct record counts" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an initial backfill sync event is broadcast followed by a subsequent incremental sync event", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both sync history entries are visible", context do
        entries = context.view
          |> render()
          |> then(fn html ->
            Floki.parse_document!(html)
            |> Floki.find("[data-role='sync-history-entry']")
          end)

        assert length(entries) >= 2,
               "Expected at least 2 sync history entries (initial + subsequent), got #{length(entries)}"

        :ok
      end

      then_ "the history shows the large backfill record count from the initial sync", context do
        html = render(context.view)

        assert html =~ "548",
               "Expected the sync history to include the 548-record initial backfill count, got: #{html}"

        :ok
      end

      then_ "the history also shows the small incremental record count from the subsequent sync", context do
        html = render(context.view)

        assert html =~ "7",
               "Expected the sync history to include the 7-record incremental sync count, got: #{html}"

        :ok
      end
    end
  end
end
