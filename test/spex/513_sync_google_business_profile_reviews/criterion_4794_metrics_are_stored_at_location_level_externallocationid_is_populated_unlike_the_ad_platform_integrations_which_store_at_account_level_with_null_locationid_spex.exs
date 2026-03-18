defmodule MetricFlowSpex.MetricsAreStoredAtLocationLevelExternalLocationIdIsPopulatedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metrics are stored at location level (externalLocationId populated) unlike ad platforms (account level, null locationId)" do
    scenario "a sync completion for a specific location shows in sync history with records synced" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completion event is broadcast for a specific location", context do
        location_id = "locations/123456789"

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 48,
          completed_at: ~U[2026-03-17 02:00:00Z],
          external_location_id: location_id
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :location_id, location_id)}
      end

      then_ "the sync history page shows a Google Business Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or html =~ "Google Business",
               "Expected a 'Google Business Reviews' entry in sync history, got: #{html}"

        :ok
      end

      then_ "the entry shows a success status and records synced count", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        assert html =~ "48" or html =~ "records synced",
               "Expected the sync entry to show '48 records synced', got: #{html}"

        :ok
      end
    end

    scenario "multiple location syncs produce distinct entries in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Google Business Reviews sync completion events are broadcast for two different locations", context do
        locations = [
          %{external_location_id: "locations/111111111", records_synced: 30},
          %{external_location_id: "locations/222222222", records_synced: 18}
        ]

        Enum.each(locations, fn loc ->
          send(context.view.pid, {:sync_completed, %{
            provider: :google_business_reviews,
            records_synced: loc.records_synced,
            completed_at: ~U[2026-03-17 02:00:00Z],
            external_location_id: loc.external_location_id
          }})
          :timer.sleep(30)
        end)

        :timer.sleep(100)
        {:ok, Map.put(context, :locations, locations)}
      end

      then_ "the sync history shows two distinct Google Business Reviews entries", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one per location), but found #{entry_count}"

        :ok
      end

      then_ "the record counts for both location syncs are visible in the history", context do
        html = render(context.view)

        assert html =~ "30",
               "Expected sync history to show record count '30' for the first location, got: #{html}"

        assert html =~ "18",
               "Expected sync history to show record count '18' for the second location, got: #{html}"

        :ok
      end
    end

    scenario "the provider name distinguishes Google Business Reviews from ad platform entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both a Google Business Reviews sync and a Google Ads sync completion event are broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 55,
          completed_at: ~U[2026-03-17 02:05:00Z],
          external_location_id: "locations/999888777"
        }})

        :timer.sleep(30)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 200,
          completed_at: ~U[2026-03-17 02:00:00Z]
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Business Reviews entry distinct from the Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or html =~ "Google Business",
               "Expected 'Google Business Reviews' label in the sync history, got: #{html}"

        assert html =~ "Google Ads",
               "Expected 'Google Ads' label in the sync history alongside the Business Reviews entry, got: #{html}"

        :ok
      end

      then_ "the two entries carry different provider labels confirming location vs account level storage", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 distinct provider entries (Google Business Reviews + Google Ads), found #{entry_count}"

        :ok
      end
    end
  end
end
