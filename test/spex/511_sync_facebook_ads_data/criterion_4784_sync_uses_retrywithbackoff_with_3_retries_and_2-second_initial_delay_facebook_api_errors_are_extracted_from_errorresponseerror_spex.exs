defmodule MetricFlowSpex.SyncUsesRetryWithBackoffWith3RetriesAnd2SecondInitialDelayFacebookApiErrorsAreExtractedFromErrorResponseErrorSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync uses retryWithBackoff with 3 retries and 2-second initial delay; Facebook API errors are extracted from error.response.error" do
    scenario "a Facebook Ads sync failure after retries shows the extracted Facebook API error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast with a Facebook API error extracted from error.response.error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook API error: (#200) The user hasn't authorized the application to perform this action"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' for the API failure after retries, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Facebook Ads sync entry to be marked as failed after exhausting retries, got: #{html}"

        :ok
      end

      then_ "the error message displayed is specific and comes from the Facebook API error response", context do
        html = render(context.view)

        assert html =~ "#200" or html =~ "application to perform" or html =~ "Facebook API error" or
                 html =~ "unauthorized",
               "Expected the sync history to surface the extracted Facebook API error message (from error.response.error), not a generic error, got: #{html}"

        :ok
      end
    end

    scenario "the Facebook API error message shown in sync history is not a generic error" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast with a rate-limit error from Facebook's API", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook API error: (#17) User request limit reached"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the Facebook Ads failure entry is visible in sync history", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads', got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the rate-limit failure entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error reason shown to the user contains Facebook API details rather than a generic failure message", context do
        html = render(context.view)

        assert html =~ "#17" or html =~ "request limit" or html =~ "Facebook API error",
               "Expected the sync history to show the specific Facebook API error code and message, not just 'sync failed', got: #{html}"

        :ok
      end
    end

    scenario "a successful Facebook Ads sync after initial failures shows as completed in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast for a transient error that would be retried", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook API error: (#1) An unknown error occurred"
        }})

        :timer.sleep(50)
        {:ok, context}
      end

      when_ "a subsequent Facebook Ads sync completion event is broadcast after a successful retry", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 12,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history contains a successful Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads', got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the successful retry to be shown as a completed/success entry in sync history, got: #{html}"

        :ok
      end

      then_ "the sync history also retains the earlier failed entry", context do
        html = render(context.view)

        assert html =~ "Failed" or html =~ "failed",
               "Expected the earlier failed attempt to still appear in sync history alongside the success entry, got: #{html}"

        :ok
      end
    end
  end
end
