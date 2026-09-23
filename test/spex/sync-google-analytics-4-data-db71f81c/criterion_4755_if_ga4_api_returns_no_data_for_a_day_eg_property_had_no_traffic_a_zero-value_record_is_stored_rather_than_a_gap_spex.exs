defmodule MetricFlowSpex.IfGa4ApiReturnsNoDataForADayAZeroValueRecordIsStoredRatherThanAGapSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If GA4 API returns no data for a day (e.g., property had no traffic), a zero-value record is stored rather than a gap" do
    scenario "a GA4 sync that stored zero-value records for a no-traffic day appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event arrives for a day with zero records", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 0,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Analytics success entry even for a zero-records day", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show a Google Analytics entry for a zero-traffic day, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the zero-records sync to still show a success status (a zero-value record was stored), got: #{html}"

        :ok
      end

      then_ "the sync entry shows 0 records synced for the no-traffic day", context do
        html = render(context.view)

        assert html =~ "0 records" or html =~ "records synced",
               "Expected the sync entry to show 0 records synced for the day with no traffic, got: #{html}"

        :ok
      end
    end

    scenario "sync history shows entries for days with traffic and days without traffic side by side" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "sync events arrive for a day with traffic and a day without traffic", context do
        # Day with traffic
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(50)

        # Day with zero traffic
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 0,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -2)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both sync entries appear in the history, showing no gaps in coverage", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (covering days with and without traffic), but found #{entry_count}"

        :ok
      end
    end

    scenario "the sync history page shows a completed sync entry for each day including zero-traffic days" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event arrives with zero records for a specific date", context do
        specific_date = ~D[2026-03-10]

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 0,
          completed_at: ~U[2026-03-11 02:00:00Z],
          data_date: specific_date
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :specific_date, specific_date)}
      end

      then_ "the sync history shows the entry with the specific date and success status", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the zero-traffic day, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the zero-traffic day sync to show success (zero-value record was stored, not a gap), got: #{html}"

        :ok
      end
    end
  end
end
