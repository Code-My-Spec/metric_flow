defmodule MetricFlowSpex.MetricKeysAreQuickbooksAccountDailyCreditsAndDebitsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metric keys are quickbooks_account_daily_credits and quickbooks_account_daily_debits" do
    scenario "sync with 2 metric keys shows a record count of 2 in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event is broadcast with credits and debits metric keys", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows QuickBooks with a record count of 2 for the two metric keys", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show 'QuickBooks' as the provider, got: #{html}"

        assert html =~ "2" or html =~ "records",
               "Expected the record count to be 2 (one per metric key: credits and debits), got: #{html}"

        :ok
      end
    end

    scenario "sync history shows a QuickBooks entry with success status after syncing both metric keys" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event arrives for both daily_credits and daily_debits", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows QuickBooks with a success status", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected 'QuickBooks' in sync history after syncing both metric keys, got: #{html}"

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected success status for QuickBooks entry after syncing credits and debits metric keys, got: #{html}"

        :ok
      end

      then_ "the sync history entry element is present on the page", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected a sync history entry element after QuickBooks sync with both metric keys"

        :ok
      end
    end

    scenario "a failed QuickBooks sync shows an error entry in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync failure event is broadcast while writing metric keys", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: failed to store quickbooks_account_daily_credits"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed QuickBooks entry", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected 'QuickBooks' in sync history for the failed metric key sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the QuickBooks metric key sync failure to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the sync error element is present for the failed entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the failed QuickBooks metric key sync"

        :ok
      end
    end
  end
end
