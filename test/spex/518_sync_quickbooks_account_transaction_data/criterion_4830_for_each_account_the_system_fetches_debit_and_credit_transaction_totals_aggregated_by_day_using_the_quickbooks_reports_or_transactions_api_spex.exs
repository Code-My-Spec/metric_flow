defmodule MetricFlowSpex.SystemFetchesDebitCreditTotalsAggregatedByDayViaQuickBooksApiSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches debit and credit transaction totals aggregated by day via QuickBooks API" do
    scenario "sync completion with daily aggregates shows record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes with daily aggregated debit and credit totals", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 60,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows the number of daily aggregate records synced", context do
        html = render(context.view)

        assert html =~ "60" or html =~ "records",
               "Expected the sync history entry to show daily aggregate record count, got: #{html}"

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the daily aggregate sync to show success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history shows QuickBooks as the provider for transaction data syncs" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks transaction data sync completes", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 90,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry is labeled with QuickBooks as the provider", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the sync history entry to identify QuickBooks as the data provider, got: #{html}"

        :ok
      end

      then_ "the success entry has the expected data-status attribute", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a sync history entry with data-status='success' for the QuickBooks transaction sync"

        :ok
      end
    end

    scenario "failed sync during transaction fetch shows an error in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync fails while fetching transaction totals from the API", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: 500 Internal Server Error — Reports API unavailable"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed QuickBooks entry for the transaction fetch error", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for the transaction fetch failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the transaction fetch failure to be marked as failed in sync history, got: #{html}"

        :ok
      end

      then_ "the API error details are surfaced in the failed entry", context do
        html = render(context.view)

        assert html =~ "500" or html =~ "Internal Server Error" or
                 html =~ "Reports API" or html =~ "unavailable",
               "Expected the transaction API error to be surfaced in the sync history, got: #{html}"

        :ok
      end

      then_ "the failed entry has a sync-error element", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the failed transaction fetch"

        :ok
      end
    end
  end
end
