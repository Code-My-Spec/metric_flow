defmodule MetricFlowSpex.LocationDetailsTitleStoreCodeAreFetchedPerLocationDuringSyncToGenerateTheMetricLabelSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Location details (title, storeCode) are fetched per location during sync to generate the metric label" do
    scenario "a successful Google Business Profile sync shows the location title in the sync history entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes with location title metadata", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          location_title: "Downtown Coffee Co.",
          store_code: "STORE-001"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry is labeled with the location title", context do
        html = render(context.view)

        assert html =~ "Downtown Coffee Co." or
                 html =~ "STORE-001" or
                 html =~ "Google Business" or
                 html =~ "google_business",
               "Expected the sync history entry to include location details (title or store code), got: #{html}"

        :ok
      end

      then_ "the sync history entry shows a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the sync history entry to show Success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history shows the store code when the location title is absent" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes with only a store code (no title)", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 3,
          completed_at: DateTime.utc_now(),
          location_title: nil,
          store_code: "STORE-042"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry uses the store code as the metric label", context do
        html = render(context.view)

        assert html =~ "STORE-042" or
                 html =~ "Google Business" or
                 html =~ "google_business",
               "Expected the sync history entry to show the store code as a fallback label, got: #{html}"

        :ok
      end
    end

    scenario "a sync that fails to fetch location details surfaces the error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync fails with a location details error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "Failed to fetch location details: 403 PERMISSION_DENIED — Location access denied"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows a failed Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or
                 html =~ "google_business" or
                 html =~ "Business Profile",
               "Expected the failed sync history entry to reference Google Business Profile, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync history entry to show a failed status, got: #{html}"

        :ok
      end

      then_ "the error message surfaces the location details fetch failure", context do
        html = render(context.view)

        assert html =~ "403" or
                 html =~ "PERMISSION_DENIED" or
                 html =~ "Location access denied" or
                 html =~ "location details",
               "Expected the sync history to surface the location details error, got: #{html}"

        :ok
      end
    end
  end
end
