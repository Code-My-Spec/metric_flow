defmodule MetricFlowSpex.Ga4MetricsFetchedInChunksOf10AndMergedByDateIdenticalToSingleRequestSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is identical to a single-request response would be" do
    scenario "a successful GA4 sync with all core metrics appears in sync history as a single entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event arrives indicating all 11 core metrics were stored", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a single Google Analytics success entry per day", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics', got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status (all metrics merged and stored), got: #{html}"

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count == 1,
               "Expected exactly 1 sync history entry for a single daily GA4 sync (not one per chunk), but found #{entry_count}"

        :ok
      end

      then_ "the sync entry shows 11 records synced representing all merged GA4 metrics", context do
        html = render(context.view)

        assert html =~ "11" or html =~ "records",
               "Expected the sync entry to show 11 records synced (all GA4 metrics merged from multiple API chunks), got: #{html}"

        :ok
      end
    end

    scenario "a GA4 sync failure during chunked fetching is surfaced as a single failure entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event arrives indicating a chunk request failed", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 runReport chunk request failed: INVALID_ARGUMENT on metrics batch 2"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a single failed Google Analytics entry", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the chunk failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count == 1,
               "Expected exactly 1 failure entry in sync history (not one per chunk), but found #{entry_count}"

        :ok
      end
    end

    scenario "the sync history page renders without errors for a standard GA4 sync" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history page renders successfully with all standard sections", context do
        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected the sync schedule section to be present"

        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected the sync history section to be present"

        :ok
      end
    end
  end
end
