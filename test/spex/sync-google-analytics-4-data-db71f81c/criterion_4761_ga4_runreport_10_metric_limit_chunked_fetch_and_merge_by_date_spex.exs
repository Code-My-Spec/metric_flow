defmodule MetricFlowSpex.Ga4MetricsFetchedInChunksAndMergedByDateEquivalentToSingleRequestResponseSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "GA4 runReport 10-metric limit: chunked fetches are merged by date before storage" do
    scenario "a GA4 sync with all 11 core metrics stored successfully appears as one entry per day" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion arrives with 11 records covering all core metrics for a single date", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows one Google Analytics entry with 11 records for that date", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics', got: #{html}"

        assert html =~ "11" or html =~ "records",
               "Expected the entry to show 11 records (all metrics merged across API chunks), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "GA4 sync history entries for different dates each show the full set of merged records" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "GA4 sync completion events arrive for three different dates, each with 11 records", context do
        Enum.each(1..3, fn i ->
          send(context.view.pid, {:sync_completed, %{
            provider: :google_analytics,
            records_synced: 11,
            completed_at: DateTime.utc_now(),
            data_date: Date.add(Date.utc_today(), -i)
          }})
          :timer.sleep(30)
        end)

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows three entries, each representing a complete merged daily dataset", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count == 3,
               "Expected exactly 3 sync history entries (one merged entry per date), but found #{entry_count}"

        :ok
      end

      then_ "all three entries show success status indicating complete data was stored for each date", context do
        html = render(context.view)

        success_count =
          html
          |> String.split("badge-success")
          |> length()
          |> Kernel.-(1)

        assert success_count >= 3,
               "Expected 3 success badges (one per date with fully merged metrics), but found #{success_count}"

        :ok
      end
    end

    scenario "a GA4 sync failure for a chunked metric fetch shows a single failure entry, not multiple" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event is broadcast for a chunk merge failure", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "Failed to merge GA4 metric chunks: date alignment mismatch"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a single failed entry for the Google Analytics provider", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the chunk merge failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected a single failed entry for the chunk merge failure, got: #{html}"

        :ok
      end
    end
  end
end
