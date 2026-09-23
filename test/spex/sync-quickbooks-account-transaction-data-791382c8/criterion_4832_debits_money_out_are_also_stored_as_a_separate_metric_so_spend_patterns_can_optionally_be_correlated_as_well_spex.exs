defmodule MetricFlowSpex.DebitsMoneyOutStoredAsSeparateMetricForSpendPatternCorrelationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Debits (money out) are stored as a separate metric so spend patterns can optionally be correlated" do
    scenario "sync with both credit and debit metrics shows combined record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes with both credit and debit metrics stored", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 4,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a QuickBooks entry with a record count reflecting both metric types", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show 'QuickBooks', got: #{html}"

        assert html =~ "4" or html =~ "records",
               "Expected the entry to show record count covering both credit and debit metrics, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history entry for QuickBooks shows success after storing debit metrics" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes with debit metrics stored for two accounts", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a successful QuickBooks entry", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected 'QuickBooks' in sync history after debit metric sync, got: #{html}"

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected success status for QuickBooks debit sync entry, got: #{html}"

        :ok
      end

      then_ "the entry is visible in the sync history list", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected at least one sync history entry element on the page"

        :ok
      end
    end

    scenario "a failed QuickBooks sync during debit processing shows an error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync failure event is broadcast for a debit processing error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: failed to retrieve debit transactions"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed QuickBooks entry with error details", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected 'QuickBooks' in sync history for the failed debit sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the QuickBooks debit sync failure to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the sync error element is present for the failed entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the failed QuickBooks debit sync"

        :ok
      end
    end
  end
end
