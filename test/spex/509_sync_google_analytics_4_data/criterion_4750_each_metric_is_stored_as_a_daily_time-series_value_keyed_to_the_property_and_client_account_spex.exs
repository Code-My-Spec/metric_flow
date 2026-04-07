defmodule MetricFlowSpex.EachMetricIsStoredAsADailyTimeSeriesValueKeyedToThePropertyAndClientAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each metric is stored as a daily time-series value keyed to the property and client account" do
    scenario "sync history shows a Google Analytics entry with a specific data date" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event is broadcast with a specific data date", context do
        data_date = ~D[2026-03-15]

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: ~U[2026-03-16 02:00:00Z],
          data_date: data_date
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :data_date, data_date)}
      end

      then_ "the sync history entry shows the specific date the data was collected for", context do
        html = render(context.view)
        expected_date = Date.to_iso8601(context.data_date)

        assert html =~ expected_date,
               "Expected sync history entry to show the data date '#{expected_date}', but not found in: #{html}"

        :ok
      end

      then_ "the sync history entry is associated with the Google Analytics provider", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the sync history entry to be keyed to 'Google Analytics', got: #{html}"

        :ok
      end
    end

    scenario "sync history shows separate entries for each day a GA4 sync ran" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "GA4 sync completion events arrive for three different dates", context do
        dates = [~D[2026-03-13], ~D[2026-03-14], ~D[2026-03-15]]

        Enum.each(dates, fn date ->
          send(context.view.pid, {:sync_completed, %{
            provider: :google_analytics,
            records_synced: 11,
            completed_at: ~U[2026-03-16 02:00:00Z],
            data_date: date
          }})
          :timer.sleep(30)
        end)

        :timer.sleep(100)
        {:ok, Map.put(context, :dates, dates)}
      end

      then_ "the sync history shows three separate Google Analytics entries", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 3,
               "Expected at least 3 sync history entries (one per data date), but found #{entry_count}"

        :ok
      end

      then_ "each entry displays its distinct data date", context do
        html = render(context.view)

        Enum.each(context.dates, fn date ->
          assert html =~ Date.to_iso8601(date),
                 "Expected sync history to include entry for date '#{Date.to_iso8601(date)}'"
        end)

        :ok
      end
    end

    scenario "sync history page shows the date range for stored data" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a date range indicating the time-series data coverage", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='date-range']"),
               "Expected a [data-role='date-range'] element showing the time-series coverage"

        assert html =~ "yesterday" or html =~ "today excluded",
               "Expected the date range section to indicate that today is excluded and yesterday is the latest date"

        :ok
      end
    end
  end
end
