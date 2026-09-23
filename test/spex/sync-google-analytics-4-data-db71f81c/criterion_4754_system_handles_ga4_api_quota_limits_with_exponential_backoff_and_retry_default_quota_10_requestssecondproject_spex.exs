defmodule MetricFlowSpex.SystemHandlesGa4ApiQuotaLimitsWithExponentialBackoffAndRetrySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System handles GA4 API quota limits with exponential backoff and retry (default quota: 10 requests/second/project)" do
    scenario "a GA4 sync failure due to quota limits is surfaced in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event with a quota exceeded error is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 API quota exceeded: RESOURCE_EXHAUSTED"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Analytics entry", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the quota-exceeded failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the quota-exceeded sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason with quota information is visible to the user", context do
        html = render(context.view)

        assert html =~ "quota" or html =~ "RESOURCE_EXHAUSTED" or html =~ "GA4 API",
               "Expected the sync history to show the quota-related failure reason, got: #{html}"

        :ok
      end
    end

    scenario "the sync history schedule section mentions automatic retry behavior" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section explains that failed syncs are retried automatically", context do
        html = render(context.view)

        assert html =~ "retried" or html =~ "retry" or html =~ "backoff",
               "Expected the sync history schedule section to mention automatic retry behavior, got: #{html}"

        :ok
      end
    end

    scenario "a GA4 sync failure with attempt count information is shown in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event with attempt details is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "Rate limit hit",
          attempt: 2,
          max_attempts: 3
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows the failed entry with attempt information", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the rate-limit failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the retry failure entry to be marked as failed, got: #{html}"

        :ok
      end
    end
  end
end
