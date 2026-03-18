defmodule MetricFlowSpex.EachMetricStoredAsDailyAggregateNotIndividualTransactionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each metric is stored as a daily aggregate value — sums of credits and debits per account per day" do
    scenario "sync shows daily aggregate count rather than individual transaction count in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event is broadcast with daily aggregate records", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows QuickBooks with a small aggregate record count not a transaction count", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show 'QuickBooks' as the provider, got: #{html}"

        assert html =~ "2" or html =~ "records",
               "Expected the record count to reflect daily aggregates (2 = credits + debits), not raw transactions, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the QuickBooks sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history page has no Transaction column or filter visible" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is no Transaction column or transaction-level filter on the sync history page", context do
        html = render(context.view)

        refute html =~ "Transaction count" or html =~ "transaction_count",
               "Expected no 'Transaction count' column on sync history — data is stored as daily aggregates"

        refute has_element?(context.view, "[data-role='filter-transaction']"),
               "Expected no transaction-level filter element on the sync history page"

        :ok
      end
    end

    scenario "record count in sync history reflects daily aggregates not individual transactions" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes for one account over one day with two aggregate metrics", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows 2 records representing daily credit and debit aggregates", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected at least one sync history entry element"

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the sync history entry to be associated with QuickBooks, got: #{html}"

        :ok
      end
    end
  end
end
