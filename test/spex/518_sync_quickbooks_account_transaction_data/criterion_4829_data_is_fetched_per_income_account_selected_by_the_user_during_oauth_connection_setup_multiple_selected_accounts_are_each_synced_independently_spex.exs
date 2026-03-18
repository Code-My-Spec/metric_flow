defmodule MetricFlowSpex.DataFetchedPerIncomeAccountMultipleAccountsSyncedIndependentlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data fetched per income account; multiple selected accounts are each synced independently" do
    scenario "per-account sync shows record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completes for a single income account with records", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 30,
          completed_at: DateTime.utc_now(),
          account_name: "Checking Account"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows the number of records synced for that account", context do
        html = render(context.view)

        assert html =~ "30" or html =~ "records",
               "Expected the sync history entry to show the record count for the income account, got: #{html}"

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the sync history entry to be associated with QuickBooks, got: #{html}"

        :ok
      end
    end

    scenario "multiple income account syncs produce distinct entries in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "QuickBooks syncs complete for two different income accounts", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 15,
          completed_at: DateTime.utc_now(),
          account_name: "Checking Account"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 22,
          completed_at: DateTime.utc_now(),
          account_name: "Savings Account"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows at least two QuickBooks sync entries", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one per income account), but found #{entry_count}"

        :ok
      end

      then_ "the sync history entries are each marked as successful", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected sync history entries with data-status='success' for the completed account syncs"

        :ok
      end
    end

    scenario "failed sync for one income account shows an error entry in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync fails for one income account", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :quickbooks,
          reason: "QuickBooks API error: account not found — income account ID 987 is invalid",
          account_name: "Business Checking"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed QuickBooks entry for the failing account", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show a QuickBooks entry for the failed account sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the per-account failure to be marked as failed in sync history, got: #{html}"

        :ok
      end

      then_ "the failed entry has a sync-error element", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the failed income account sync"

        :ok
      end

      when_ "the user filters sync history by Failed status", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "the failed income account entry is visible in the filtered results", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the failed QuickBooks income account entry to appear in the Failed filter, got: #{html}"

        :ok
      end
    end
  end
end
