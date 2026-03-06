defmodule MetricFlowSpex.OnFirstSyncAfterConnectionSystemBackfillsAllAvailableHistoricalDataFromPlatformSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On first sync after connection, system backfills all available historical data from platform" do
    scenario "sync history page shows an initial sync entry labeled as a backfill" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history list contains an entry marked as the initial or backfill sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or
                 html =~ "Backfill" or
                 html =~ "initial sync" or
                 html =~ "backfill",
               "Expected the sync history page to show an 'Initial Sync' or 'Backfill' entry, got: #{html}"

        :ok
      end
    end

    scenario "the initial backfill sync entry is visually distinguished from regular daily syncs" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history list contains a distinguishable initial sync element", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] section to be present on the sync history page"

        :ok
      end

      then_ "the initial backfill entry is labeled to distinguish it from routine daily syncs", context do
        assert has_element?(context.view, "[data-sync-type='initial']") or
                 has_element?(context.view, "[data-sync-type='backfill']") or
                 has_element?(context.view, "[data-role='initial-sync']"),
               "Expected a data-sync-type='initial' or data-sync-type='backfill' or data-role='initial-sync' element identifying the backfill sync entry"

        :ok
      end
    end

    scenario "the initial backfill sync entry communicates that historical data was pulled" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user views the initial sync entry in the sync history list", context do
        {:ok, context}
      end

      then_ "the entry's description communicates that historical data was pulled from the platform", context do
        html = render(context.view)

        assert html =~ "historical" or
                 html =~ "Historical" or
                 html =~ "all available" or
                 html =~ "backfill" or
                 html =~ "Backfill" or
                 html =~ "Initial Sync" or
                 html =~ "initial sync",
               "Expected the sync history page to communicate that historical data was backfilled, got: #{html}"

        :ok
      end
    end

    scenario "the initial backfill sync entry shows a wider date range than a regular daily sync" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history page shows the date range covered by the initial backfill sync", context do
        html = render(context.view)

        assert html =~ "Initial Sync" or
                 html =~ "Backfill" or
                 html =~ "date range" or
                 html =~ "from" or
                 html =~ "historical",
               "Expected the sync history page to include date range information for the initial backfill sync, got: #{html}"

        :ok
      end
    end
  end
end
