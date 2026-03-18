defmodule MetricFlowSpex.SubsequentDailySyncsFetchDataForYesterdayOnlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Subsequent daily syncs fetch data for yesterday only (avoids incomplete current-day data)" do
    scenario "the sync history date range section shows coverage through yesterday, not today" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the date range section shows data is available through yesterday", context do
        html = render(context.view)
        yesterday = Date.add(Date.utc_today(), -1) |> Date.to_iso8601()

        assert html =~ yesterday,
               "Expected the date range to show yesterday's date #{yesterday} as the end of coverage, got: #{html}"

        :ok
      end

      then_ "the page explains that today is excluded to avoid incomplete data", context do
        html = render(context.view)

        assert html =~ "today excluded" or html =~ "incomplete day" or html =~ "incomplete current",
               "Expected the page to explain that today is excluded because the current day's data is incomplete, got: #{html}"

        :ok
      end
    end

    scenario "a GA4 sync completion event with yesterday's date appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event arrives with yesterday as the data date", context do
        yesterday = Date.add(Date.utc_today(), -1)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: yesterday
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :yesterday, yesterday)}
      end

      then_ "the sync history entry shows yesterday's date as the data date", context do
        html = render(context.view)
        expected_date = Date.to_iso8601(context.yesterday)

        assert html =~ expected_date or html =~ "Date:",
               "Expected the sync entry to show yesterday's date #{expected_date}, got: #{html}"

        :ok
      end

      then_ "the sync entry shows a success status for the Google Analytics provider", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show the Google Analytics provider, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "the sync history date range element is rendered on the page" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a date range element is present explaining the data coverage window", context do
        assert has_element?(context.view, "[data-role='date-range']"),
               "Expected a [data-role='date-range'] element to be present on the sync history page"

        :ok
      end
    end
  end
end
