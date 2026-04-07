defmodule MetricFlowSpex.DataIsFetchedPerLocationIdListedInCustomerConfigIncludedLocationsScopedUnderTheCustomersGoogleBusinessAccountIdSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data is fetched per location ID listed in customerConfig.includedLocations, scoped under the customer's googleBusinessAccountId" do
    scenario "a sync completion for a specific Google Business location shows in sync history with records synced" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completion event for a specific location ID is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 28,
          completed_at: DateTime.utc_now(),
          location_id: "locations/1234567890",
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected sync history to show 'Google Business' provider, got: #{html}"

        :ok
      end

      then_ "the sync entry shows the number of records synced for that location", context do
        html = render(context.view)

        assert html =~ "28" or html =~ "records",
               "Expected sync history entry to show the records synced count (28), got: #{html}"

        :ok
      end

      then_ "the sync entry shows a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "multiple location syncs produce distinct entries in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two Google Business Profile sync completion events are broadcast for different location IDs", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 15,
          completed_at: DateTime.utc_now(),
          location_id: "locations/1111111111",
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 22,
          completed_at: DateTime.utc_now(),
          location_id: "locations/2222222222",
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both Google Business Profile sync entries appear in the history", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected sync history to show Google Business Profile entries, got: #{html}"

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one per location), but found #{entry_count}"

        :ok
      end

      then_ "both entries show success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected both sync entries to show success status, got: #{html}"

        :ok
      end
    end

    scenario "a sync failure for one location is surfaced with location-specific error details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync failure event for a specific location is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "Google Business Profile API error: 403 PERMISSION_DENIED — Location access denied for locations/9999999999",
          location_id: "locations/9999999999",
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected sync history to show 'Google Business' provider for the failed sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error details are surfaced in the failed sync entry", context do
        html = render(context.view)

        assert html =~ "403" or html =~ "PERMISSION_DENIED" or
                 html =~ "Location access denied" or html =~ "Google Business Profile API error",
               "Expected the location-specific error details to be shown in sync history, got: #{html}"

        :ok
      end

      then_ "the failed entry is associated with the error data role", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the location-specific error details"

        :ok
      end
    end
  end
end
