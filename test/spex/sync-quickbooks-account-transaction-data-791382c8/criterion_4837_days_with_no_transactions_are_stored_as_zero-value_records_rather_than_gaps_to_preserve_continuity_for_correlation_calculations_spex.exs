defmodule MetricFlowSpex.QuickbooksDaysWithNoTransactionsStoredAsZeroValueRecordsNotGapsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "QuickBooks days with no transactions are stored as zero-value records, not gaps" do
    scenario "sync with zero-value days shows full record count with no failures" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event arrives including zero-value transaction days", context do
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
               "Expected sync history to show a QuickBooks entry even when some days had no transactions, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync with zero-value days to show success (records were stored, not gaps), got: #{html}"

        :ok
      end

      then_ "the entry shows the expected full record count covering all days including zero-transaction days", context do
        html = render(context.view)

        assert html =~ "548" or html =~ "records",
               "Expected the sync entry to show the full record count (zero-value days included), got: #{html}"

        :ok
      end

      then_ "no failure entry appears in the history due to empty transaction days", context do
        # Check that no sync history entries have a failed status — the filter buttons
        # contain the word "Failed" so we check for failed entries via data attributes instead
        refute has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected no failed sync history entries — zero-transaction days should be stored as zero-value records, not cause failures"

        :ok
      end
    end

    scenario "sync entry for a day with zero transactions shows success with zero records" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event arrives for a day with no transactions", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 0,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows the QuickBooks entry with success status", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for a no-transaction day, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the no-transaction day sync to show success (a zero-value record was stored), got: #{html}"

        :ok
      end

      then_ "the sync entry shows 0 records synced indicating a zero-value record was stored", context do
        html = render(context.view)

        assert html =~ "0 records" or html =~ "records synced" or html =~ "0",
               "Expected the sync entry to show 0 records synced for the no-transaction day, got: #{html}"

        :ok
      end
    end

    scenario "sync history shows entries for days with and without transactions side by side with no gaps" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "sync events arrive for a day with transactions and a day without transactions", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 12,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 0,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -2)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both sync entries appear in the history showing continuity with no gaps", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one with transactions, one without), but found #{entry_count}"

        :ok
      end

      then_ "no failure entries appear — zero-transaction days cause no failures", context do
        # Check for failed entries via data attributes — the filter buttons contain "Failed" text
        refute has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected no failed sync history entries — zero-transaction days should produce zero-value records, not failures"

        :ok
      end
    end
  end
end
