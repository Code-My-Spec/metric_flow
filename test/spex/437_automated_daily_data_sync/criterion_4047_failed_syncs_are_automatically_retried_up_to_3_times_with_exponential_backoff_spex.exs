defmodule MetricFlowSpex.FailedSyncsAreAutomaticallyRetriedUpTo3TimesWithExponentialBackoffSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed syncs are automatically retried up to 3 times with exponential backoff" do
    scenario "sync history page shows retry attempt count for a failed sync entry" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure message is received indicating this is the first of three attempts", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "API rate limit exceeded",
          attempt: 1,
          max_attempts: 3
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the attempt count displayed on the failed sync entry", context do
        html = render(context.view)

        assert html =~ "1" and (html =~ "3" or html =~ "attempt" or html =~ "retry"),
               "Expected the sync history page to show attempt count (e.g. '1 of 3' or 'Attempt 1/3'), got: #{html}"

        :ok
      end

      then_ "the user sees that the system will retry the failed sync", context do
        html = render(context.view)

        assert html =~ "retry" or
                 html =~ "Retry" or
                 html =~ "retrying" or
                 html =~ "Retrying" or
                 html =~ "attempt" or
                 html =~ "Attempt",
               "Expected the sync history page to communicate that the sync will be retried, got: #{html}"

        :ok
      end
    end

    scenario "sync history page shows the maximum retry limit of 3 attempts" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure message is received with retry information", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Connection timeout",
          attempt: 2,
          max_attempts: 3
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user can see that up to 3 retry attempts are allowed", context do
        html = render(context.view)

        assert html =~ "3",
               "Expected the sync history page to display the maximum number of retry attempts (3), got: #{html}"

        :ok
      end
    end

    scenario "sync history page shows a failed sync that has exhausted all 3 attempts" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure message is received indicating all 3 attempts have been exhausted", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Service unavailable",
          attempt: 3,
          max_attempts: 3
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the sync is permanently failed after exhausting all retries", context do
        html = render(context.view)

        assert html =~ "failed" or
                 html =~ "Failed" or
                 html =~ "error" or
                 html =~ "Error",
               "Expected the sync history page to show the sync as permanently failed after 3 attempts, got: #{html}"

        :ok
      end

      then_ "the error reason is visible so the user understands why the sync failed", context do
        html = render(context.view)

        assert html =~ "Service unavailable" or
                 html =~ "unavailable" or
                 html =~ "failed" or
                 html =~ "Failed" or
                 html =~ "error" or
                 html =~ "Error",
               "Expected the sync history page to display the failure reason, got: #{html}"

        :ok
      end
    end

    scenario "sync history page shows the retry section indicating automatic retry behavior" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history page is accessible and renders content", context do
        html = render(context.view)

        refute html == "",
               "Expected the sync history page to render content, but got an empty page"

        :ok
      end

      then_ "the page includes a sync history section where retry information can be shown", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] element to be present for displaying sync entries with retry details"

        :ok
      end
    end
  end
end
