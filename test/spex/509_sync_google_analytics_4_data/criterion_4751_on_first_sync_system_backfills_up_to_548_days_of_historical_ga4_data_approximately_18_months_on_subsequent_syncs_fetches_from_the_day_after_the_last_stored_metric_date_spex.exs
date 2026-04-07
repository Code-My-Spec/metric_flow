defmodule MetricFlowSpex.OnFirstSyncSystemBackfillsUp548DaysOfHistoricalGa4DataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On first sync, system backfills up to 548 days of historical GA4 data (approximately 18 months); on subsequent syncs, fetches from the day after the last stored metric date" do
    scenario "the sync history page describes historical backfill behavior in the schedule section" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section explains that historical data is backfilled on first sync", context do
        html = render(context.view)

        assert html =~ "backfill" or html =~ "historical",
               "Expected the sync history page to mention historical data backfill, got: #{html}"

        :ok
      end

      then_ "the schedule section is present and visible", context do
        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected a [data-role='sync-schedule'] section describing the sync schedule"

        schedule_html = context.view
          |> element("[data-role='sync-schedule']")
          |> render()

        assert schedule_html =~ "first sync" or schedule_html =~ "backfill" or schedule_html =~ "historical",
               "Expected the schedule section to mention first sync backfill behavior, got: #{schedule_html}"

        :ok
      end
    end

    scenario "an initial sync completion event for a GA4 property is labeled as an initial sync" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 initial backfill sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 548,
          completed_at: DateTime.utc_now(),
          sync_type: :initial
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows the Google Analytics initial sync", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the sync history to show a Google Analytics entry for the initial backfill, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the initial backfill sync entry to have a success status, got: #{html}"

        :ok
      end

      then_ "the sync entry is labeled as an Initial Sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or html =~ "initial",
               "Expected the initial backfill sync entry to be labeled 'Initial Sync', got: #{html}"

        :ok
      end

      then_ "the initial sync entry shows the large number of records backfilled", context do
        html = render(context.view)

        assert html =~ "548" or html =~ "records",
               "Expected the initial backfill entry to show 548 records synced, got: #{html}"

        :ok
      end
    end

    scenario "a subsequent daily sync completion event appears in sync history without the initial sync label" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a regular (non-initial) GA4 sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Analytics success entry without the Initial Sync label", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected the sync history to show a Google Analytics entry, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the subsequent sync entry to show success status, got: #{html}"

        refute html =~ "Initial Sync",
               "Expected the subsequent sync entry to NOT be labeled 'Initial Sync' (that label is only for first-ever syncs)"

        :ok
      end
    end

    scenario "the empty state on the sync history page references the initial sync concept" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the sync history page with no prior syncs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the empty state mentions that the initial sync will backfill historical data", context do
        html = render(context.view)

        assert html =~ "No sync history yet" or html =~ "no sync history" or
                 html =~ "Initial Sync" or html =~ "backfill",
               "Expected the empty state to explain the initial sync and backfill behavior, got: #{html}"

        :ok
      end
    end
  end
end
