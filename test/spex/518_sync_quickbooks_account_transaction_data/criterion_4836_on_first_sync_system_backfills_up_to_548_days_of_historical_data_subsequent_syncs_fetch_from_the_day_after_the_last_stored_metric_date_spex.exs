defmodule MetricFlowSpex.QuickbooksFirstSyncBackfills548DaysSubsequentSyncsFetchIncrementallySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "QuickBooks first sync backfills up to 548 days; subsequent syncs fetch from day after last stored metric date" do
    scenario "first sync completion event with large record count appears as initial backfill in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks initial backfill sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a QuickBooks entry with success status", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the initial backfill sync entry to have a success status, got: #{html}"

        :ok
      end

      then_ "the initial sync entry shows the large backfill record count", context do
        html = render(context.view)

        assert html =~ "548" or html =~ "records",
               "Expected the initial backfill entry to show 548 records synced, got: #{html}"

        :ok
      end

      then_ "the entry is labeled as an initial sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or html =~ "initial" or html =~ "backfill",
               "Expected the initial backfill sync entry to be labeled 'Initial Sync', got: #{html}"

        :ok
      end
    end

    scenario "subsequent incremental sync shows smaller record count without initial sync label" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks incremental sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 3,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a QuickBooks success entry without the Initial Sync label", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for the incremental sync, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the incremental sync entry to show success status, got: #{html}"

        refute html =~ "Initial Sync",
               "Expected the incremental sync entry to NOT be labeled 'Initial Sync' (that label is only for the first-ever sync)"

        :ok
      end
    end

    scenario "both first sync and subsequent sync entries appear together in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both a QuickBooks initial backfill and an incremental sync event are broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 3,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both entries appear in the sync history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 QuickBooks sync history entries (initial backfill + incremental), but found #{entry_count}"

        :ok
      end

      then_ "the history includes a record with the large backfill count", context do
        html = render(context.view)

        assert html =~ "548",
               "Expected sync history to include the 548-record initial backfill entry, got: #{html}"

        :ok
      end
    end
  end
end
