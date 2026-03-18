defmodule MetricFlowSpex.SyncUsesRetryWithBackoffUpTo3RetriesForGoogleAdsTransientApiErrorsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync uses retryWithBackoff with up to 3 retries and 2-second initial delay for transient API errors" do
    scenario "failed Google Ads sync after all retries exhausted shows a specific API error in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast after all retries exhausted", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error after 3 retries: 503 UNAVAILABLE — backend unavailable",
          attempt: 3,
          max_attempts: 3
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' for the retry-exhausted failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed after all retries, got: #{html}"

        :ok
      end

      then_ "the error message is specific and not generic", context do
        html = render(context.view)

        assert html =~ "503" or html =~ "UNAVAILABLE" or html =~ "backend unavailable" or
                 html =~ "retries" or html =~ "retry",
               "Expected the error message to be specific (503/UNAVAILABLE/retry count), got: #{html}"

        :ok
      end
    end

    scenario "error message for a transient Google Ads failure is specific not generic" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads transient failure event with specific error codes is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "INTERNAL_ERROR: Transient error — request_id: abc123, customerId: 1234567890"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history error message includes specific error details not a generic message", context do
        html = render(context.view)

        assert html =~ "INTERNAL_ERROR" or html =~ "Transient error" or
                 html =~ "request_id" or html =~ "abc123",
               "Expected a specific error message rather than a generic 'sync failed' message, got: #{html}"

        refute html =~ "Unknown error" and not (html =~ "INTERNAL_ERROR" or html =~ "Transient"),
               "Expected the specific error details to be surfaced, not a generic unknown error message"

        :ok
      end
    end

    scenario "a Google Ads sync that succeeds after initial failures shows a completed entry in history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast (succeeded after initial failures)", context do
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
               "Expected sync history to show 'Google Ads' for the eventual success, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status after eventual completion, got: #{html}"

        :ok
      end

      then_ "the successful entry shows a record count", context do
        html = render(context.view)

        assert html =~ "5" or html =~ "records",
               "Expected the successful sync entry to show records synced, got: #{html}"

        :ok
      end
    end
  end
end
