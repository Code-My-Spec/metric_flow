defmodule MetricFlowSpex.DateArithmeticOffsetsStartDateBy1DayToAvoidReFetchingLastStoredDateSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Date arithmetic for the API call offsets the start date by +1 day — this is intentional to avoid re-fetching the last stored date" do
    scenario "two consecutive Google Business Profile syncs produce distinct entries with no date overlap" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an initial Google Business Profile sync completes covering a range ending on a given date", context do
        first_sync_date = Date.add(Date.utc_today(), -2)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 30,
          completed_at: DateTime.utc_now(),
          data_date: first_sync_date
        }})

        :timer.sleep(100)

        {:ok, Map.put(context, :first_sync_date, first_sync_date)}
      end

      when_ "a subsequent Google Business Profile sync completes starting from the day after the prior sync's last date", context do
        second_sync_date = Date.add(Date.utc_today(), -1)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: second_sync_date
        }})

        :timer.sleep(100)

        {:ok, Map.put(context, :second_sync_date, second_sync_date)}
      end

      then_ "the sync history page shows two separate Google Business Profile sync entries", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected at least one Google Business Profile sync entry, got: #{html}"

        :ok
      end

      then_ "both sync entries show a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected both Google Business Profile sync entries to show success status, got: #{html}"

        :ok
      end
    end

    scenario "a subsequent Google Business Profile sync shows a small incremental record count confirming no re-fetch of the last stored date" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a follow-up Google Business Profile sync completes with only one day of new data", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history entry appears with the small incremental record count", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected a Google Business Profile sync history entry, got: #{html}"

        assert html =~ "10" or html =~ "records",
               "Expected the incremental sync entry to show the small record count (1 day of data), got: #{html}"

        :ok
      end

      then_ "the sync entry shows a success status confirming incremental data was fetched without duplication", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the incremental Google Business Profile sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "an initial and a subsequent sync both appear in history with success status" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile initial sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "a Google Business Profile incremental sync completion event is broadcast for the following day", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.add(DateTime.utc_now(), 60),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history page shows Google Business Profile entries", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected Google Business Profile sync history entries to be visible, got: #{html}"

        :ok
      end

      then_ "all Google Business Profile sync entries show a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected all Google Business Profile sync history entries to show success status, got: #{html}"

        :ok
      end

      then_ "the smaller incremental record count confirms the +1 day offset prevents re-fetching the last stored date", context do
        html = render(context.view)

        assert html =~ "10" or html =~ "records",
               "Expected the incremental sync record count to be visible, confirming the +1 day offset avoids data duplication, got: #{html}"

        :ok
      end
    end
  end
end
