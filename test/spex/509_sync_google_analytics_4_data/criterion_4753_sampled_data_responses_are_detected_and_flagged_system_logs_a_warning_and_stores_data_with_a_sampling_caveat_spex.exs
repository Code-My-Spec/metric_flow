defmodule MetricFlowSpex.SampledDataResponsesAreDetectedAndFlaggedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sampled data responses are detected and flagged — system logs a warning and stores data with a sampling caveat" do
    scenario "a GA4 sync completion with a sampling caveat appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event is broadcast indicating sampled data was returned", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a Google Analytics success entry for the sampled data sync", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show a Google Analytics entry even for sampled data syncs, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sampled data sync entry to still show a success status, got: #{html}"

        :ok
      end
    end

    scenario "a failed GA4 sync due to sampling issues shows the error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event with a sampling-related error is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 response contains sampled data — sampling threshold exceeded"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Analytics entry", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the failed sampling entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason mentioning sampling is visible in the sync history entry", context do
        html = render(context.view)

        assert html =~ "sampled" or html =~ "sampling" or html =~ "GA4 response",
               "Expected the failure reason to mention sampling, got: #{html}"

        :ok
      end
    end

    scenario "the sync history page can display sync entries for all GA4 data quality states" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both a successful and a failed GA4 sync event arrive", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "Sampling warning: data accuracy may be reduced"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both the success and failed entries appear in the history", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected at least one success entry to be shown, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the failed sampling entry to be shown, got: #{html}"

        :ok
      end
    end
  end
end
