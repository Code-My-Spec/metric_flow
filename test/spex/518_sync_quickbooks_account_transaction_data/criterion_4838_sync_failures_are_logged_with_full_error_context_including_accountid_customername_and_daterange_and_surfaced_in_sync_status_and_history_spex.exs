defmodule MetricFlowSpex.QuickbooksSyncFailuresLoggedWithFullErrorContextSurfacedInHistorySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "QuickBooks sync failures logged with full error context (accountId, customerName, dateRange) surfaced in history" do
    scenario "failed sync shows full error context including accountId, customerName, and dateRange" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync failure event with full error context is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: accountId=9341 customerName=Acme Corp dateRange=2025-01-01..2025-03-17 — 403 Forbidden"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a QuickBooks failed entry", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for the failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the QuickBooks sync failure entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error entry contains the accountId from the error context", context do
        html = render(context.view)

        assert html =~ "9341" or html =~ "accountId",
               "Expected the failure entry to surface the accountId from the error context, got: #{html}"

        :ok
      end

      then_ "the error entry contains the customerName from the error context", context do
        html = render(context.view)

        assert html =~ "Acme Corp" or html =~ "customerName",
               "Expected the failure entry to surface the customerName from the error context, got: #{html}"

        :ok
      end

      then_ "the error entry contains the dateRange from the error context", context do
        html = render(context.view)

        assert html =~ "2025-01-01" or html =~ "dateRange" or html =~ "2025-03-17",
               "Expected the failure entry to surface the dateRange from the error context, got: #{html}"

        :ok
      end
    end

    scenario "multiple QuickBooks failures with different error contexts all appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two QuickBooks sync failure events with distinct error contexts are broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: accountId=1001 customerName=Widget Co dateRange=2025-01-01..2025-01-31 — 429 Too Many Requests"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: accountId=2002 customerName=Globex Corp dateRange=2025-02-01..2025-02-28 — 500 Internal Server Error"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both failed sync entries appear in the history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 failed QuickBooks sync history entries (one per error context), but found #{entry_count}"

        :ok
      end
    end

    scenario "the Failed filter shows only failed entries and no success entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both a QuickBooks failure and a QuickBooks success event are broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: accountId=5555 customerName=Test Corp dateRange=2025-03-01..2025-03-17 — 401 Unauthorized"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      when_ "the user clicks the Failed filter", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "failed entries with data-status='failed' are visible", context do
        assert has_element?(context.view, "[data-status='failed']"),
               "Expected at least one [data-status='failed'] element after applying the Failed filter"

        :ok
      end

      then_ "no success entries with data-status='success' are visible", context do
        refute has_element?(context.view, "[data-status='success']"),
               "Expected no [data-status='success'] elements to be visible when the Failed filter is active"

        :ok
      end
    end
  end
end
