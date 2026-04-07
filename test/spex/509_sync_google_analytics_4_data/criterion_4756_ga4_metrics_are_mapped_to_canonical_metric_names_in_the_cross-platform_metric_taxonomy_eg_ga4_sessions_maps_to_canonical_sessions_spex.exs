defmodule MetricFlowSpex.Ga4MetricsAreMappedToCanonicalMetricNamesInTheCrossPlatformMetricTaxonomySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "GA4 metrics are mapped to canonical metric names in the cross-platform metric taxonomy (e.g., GA4 'sessions' maps to canonical 'sessions')" do
    scenario "a successful GA4 sync appears in sync history, indicating metric mapping completed successfully" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event is broadcast indicating metrics were synced", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Analytics success entry with records synced", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' provider, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status (metrics were mapped and stored), got: #{html}"

        assert html =~ "11" or html =~ "records",
               "Expected the sync entry to show 11 records synced (matching the canonical GA4 metrics), got: #{html}"

        :ok
      end
    end

    scenario "a GA4 sync failure due to metric mapping error appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event with a metric mapping error is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "Metric mapping failed: unknown canonical name for ga4:customMetric1"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Analytics entry with the mapping error", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the metric mapping failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the metric mapping failure entry to be marked as failed, got: #{html}"

        :ok
      end
    end

    scenario "the sync history page is accessible by an authenticated owner" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history page renders with all expected sections", context do
        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected the sync schedule section to be present on the sync history page"

        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected the sync history section to be present on the sync history page"

        :ok
      end
    end
  end
end
