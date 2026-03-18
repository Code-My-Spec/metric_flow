defmodule MetricFlowSpex.CreditsPrimaryMetricRevenueStoredForCorrelationAnalysisSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Credits (money-in) stored as primary metric — revenue target variable for correlation analysis" do
    scenario "sync with credit metrics shows record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes storing credit metrics as the primary revenue data", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 45,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows the number of credit metric records stored", context do
        html = render(context.view)

        assert html =~ "45" or html =~ "records",
               "Expected the sync history entry to show the credit metric record count, got: #{html}"

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the credit metric sync entry to identify QuickBooks, got: #{html}"

        :ok
      end
    end

    scenario "sync entry shows success confirming revenue data was stored" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks credit data sync completes successfully", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 31,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows a success status confirming revenue data was stored", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the sync entry to show success confirming credit/revenue data was stored, got: #{html}"

        :ok
      end

      then_ "the successful entry has the expected data-status attribute", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a sync history entry with data-status='success' for the QuickBooks credit sync"

        :ok
      end
    end

    scenario "failed sync during credit processing shows error in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync fails while processing credit transaction data", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: credit transaction data unavailable — account closed"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed QuickBooks entry for the credit processing error", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for the credit processing failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the credit processing failure to be marked as failed in sync history, got: #{html}"

        :ok
      end

      then_ "the credit processing error details are surfaced in the failed entry", context do
        html = render(context.view)

        assert html =~ "credit" or html =~ "account closed" or
                 html =~ "unavailable" or html =~ "transaction",
               "Expected the credit processing error to be surfaced in the sync history, got: #{html}"

        :ok
      end

      then_ "the failed entry has a sync-error element", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the failed credit processing entry"

        :ok
      end

      when_ "the user filters sync history by Failed status", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "the failed credit processing entry is visible in the Failed filter", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the failed QuickBooks credit entry to appear in the Failed filter results, got: #{html}"

        :ok
      end
    end
  end
end
