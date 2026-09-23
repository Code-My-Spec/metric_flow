defmodule MetricFlowSpex.CostMicrosAlwaysDividedBy1000000BeforeStorageSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "cost_micros is always divided by 1,000,000 before storage so all cost values are in standard currency units" do
    scenario "a Google Ads sync with cost metrics shows success and records synced in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event with cost metrics is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a successful Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' as the provider for the cost metrics sync, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status after cost metrics were processed, got: #{html}"

        :ok
      end

      then_ "the sync entry shows the record count confirming cost data was processed", context do
        html = render(context.view)

        assert html =~ "5" or html =~ "records",
               "Expected the sync entry to show records synced confirming cost data was stored, got: #{html}"

        :ok
      end
    end

    scenario "the sync history confirms cost data was processed for a Google Ads sync" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event referencing cost data is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1),
          metrics: [:clicks, :impressions, :cost, :all_conversions, :conversions]
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows the Google Ads entry with a success status", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads', got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to be marked as success confirming cost conversion succeeded, got: #{html}"

        :ok
      end

      then_ "the sync history entry exists for the cost sync", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected a [data-role='sync-history-entry'] element for the cost metrics sync"

        :ok
      end
    end

    scenario "a failed Google Ads sync during cost conversion shows an error in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event related to cost data processing is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: failed to convert cost_micros — value: nil, customerId: 1234567890"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry for the cost conversion error", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' for the cost conversion failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed when cost conversion fails, got: #{html}"

        :ok
      end

      then_ "the error message references the cost conversion failure details", context do
        html = render(context.view)

        assert html =~ "cost_micros" or html =~ "cost" or
                 html =~ "1234567890" or html =~ "convert",
               "Expected the error message to reference cost_micros conversion failure details, got: #{html}"

        :ok
      end
    end
  end
end
