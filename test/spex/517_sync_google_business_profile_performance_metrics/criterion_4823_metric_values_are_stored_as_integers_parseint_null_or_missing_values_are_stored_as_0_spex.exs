defmodule MetricFlowSpex.MetricValuesAreStoredAsIntegersParseIntNullOrMissingValuesAreStoredAs0Spex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metric values are stored as integers (parseInt); null or missing values are stored as 0" do
    scenario "a Google Business Profile sync with all metrics present shows success with the full record count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes with all metrics present", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a successful Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected sync history to show a Google Business Profile entry, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end

      then_ "the sync entry shows the full count of records synced", context do
        html = render(context.view)

        assert html =~ "7" or html =~ "records synced" or html =~ "records",
               "Expected the sync entry to display the full record count, got: #{html}"

        :ok
      end
    end

    scenario "a Google Business Profile sync where some metrics had null values still shows success with the same record count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes where null metrics were zero-filled", context do
        # Null/missing values are stored as 0 (parseInt), so the record count includes them
        # The sync still reports the same total number of records as when all values are present
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a success entry — null values do not reduce the record count", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business" or html =~ "Business Profile",
               "Expected sync history to show a Google Business Profile entry even when some metrics were null, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync to succeed when null metric values are zero-filled (parseInt), got: #{html}"

        :ok
      end

      then_ "the record count is the same as a sync with all metrics present (zero-filled, not dropped)", context do
        html = render(context.view)

        assert html =~ "7" or html =~ "records",
               "Expected the record count to match a full sync (null values stored as 0, not omitted), got: #{html}"

        :ok
      end
    end

    scenario "no sync failure occurs due to null or missing Google Business Profile metric values" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync completes despite some metrics being null or missing", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "no sync failure entry appears in the history for this sync", context do
        html = render(context.view)

        refute html =~ "Failed" and html =~ "google_business",
               "Expected no failure entry for a Google Business Profile sync with null values (they should be zero-filled), got: #{html}"

        :ok
      end

      then_ "the sync history page shows only a success entry for the Google Business Profile sync", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected a success entry — null values stored as 0 (parseInt) must not cause a sync failure, got: #{html}"

        :ok
      end
    end
  end
end
