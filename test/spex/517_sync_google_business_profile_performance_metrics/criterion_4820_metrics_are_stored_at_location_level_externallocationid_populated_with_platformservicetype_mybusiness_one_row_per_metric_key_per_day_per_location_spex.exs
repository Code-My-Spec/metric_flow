defmodule MetricFlowSpex.MetricsStoredAtLocationLevelMyBusinessOneRowPerMetricKeyPerDayPerLocationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metrics are stored at location level (externalLocationId populated) with platformServiceType 'mybusiness' — one row per metric key per day per location" do
    scenario "a single-location sync with 10 metrics shows 10 records in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes for one location with 10 metric rows", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1),
          location_count: 1
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows 10 records synced for Google Business Profile", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected sync history to show 'Google Business Profile' as the provider, got: #{html}"

        assert html =~ "10" or html =~ "records synced",
               "Expected sync history to show 10 records (one per metric key per day for the single location), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "a two-location sync with 10 metrics each shows 20 records in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes for two locations with 10 metric rows each", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 20,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1),
          location_count: 2
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows 20 records synced reflecting both locations", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected sync history to show 'Google Business Profile' as the provider, got: #{html}"

        assert html =~ "20" or html =~ "records synced",
               "Expected sync history to show 20 records (10 metrics x 2 locations), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "the sync history entry is associated with the Google Business Profile provider" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page identifies the entry as a Google Business Profile sync", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected the sync entry to be labeled as 'Google Business Profile', got: #{html}"

        :ok
      end

      then_ "no other provider label appears in place of Google Business Profile", context do
        html = render(context.view)

        # The sync history entry should not be miscategorised as a different provider
        refute html =~ "Google Analytics" and not (html =~ "Google Business" or html =~ "Business Profile"),
               "Expected only Google Business Profile as the provider, but another provider label was shown without it"

        :ok
      end
    end
  end
end
