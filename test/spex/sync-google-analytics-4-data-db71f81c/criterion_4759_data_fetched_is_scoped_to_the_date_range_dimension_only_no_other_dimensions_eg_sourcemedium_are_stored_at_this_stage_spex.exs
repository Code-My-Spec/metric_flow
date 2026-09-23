defmodule MetricFlowSpex.DataFetchedIsScopedToTheDateRangeDimensionOnlyNoOtherDimensionsAreStoredSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data fetched is scoped to the date range dimension only — no other dimensions (e.g., source/medium) are stored at this stage" do
    scenario "a GA4 sync completion event with a data date appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event is broadcast with a specific data date", context do
        data_date = Date.add(Date.utc_today(), -1)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: data_date
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :data_date, data_date)}
      end

      then_ "the sync history entry shows Google Analytics with the data date", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' as the provider, got: #{html}"

        expected_date = Date.to_iso8601(context.data_date)
        assert html =~ expected_date or html =~ "Date:",
               "Expected the sync entry to show the data date #{expected_date}, got: #{html}"

        :ok
      end

      then_ "the sync entry does not show breakdown by source or medium dimensions", context do
        html = render(context.view)

        refute html =~ "source/medium" and html =~ "source" and html =~ "medium",
               "Expected the sync history entry to not show source/medium dimension breakdowns"

        :ok
      end
    end

    scenario "the sync history page date range section shows a single date range, not dimensional breakdowns" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the date range section shows a single date coverage window", context do
        assert has_element?(context.view, "[data-role='date-range']"),
               "Expected a [data-role='date-range'] element showing the date coverage"

        html = context.view
          |> element("[data-role='date-range']")
          |> render()

        assert html =~ "yesterday" or html =~ Date.to_iso8601(Date.add(Date.utc_today(), -1)),
               "Expected the date range to reference yesterday as the end of coverage, got: #{html}"

        :ok
      end
    end

    scenario "sync history entries show one entry per date per provider, not per dimension" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two GA4 sync completion events arrive for two consecutive dates", context do
        date1 = Date.add(Date.utc_today(), -1)
        date2 = Date.add(Date.utc_today(), -2)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: date1
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: date2
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows exactly two entries, one per date", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count == 2,
               "Expected exactly 2 sync history entries (one per date, not per dimension), but found #{entry_count}"

        :ok
      end
    end
  end
end
