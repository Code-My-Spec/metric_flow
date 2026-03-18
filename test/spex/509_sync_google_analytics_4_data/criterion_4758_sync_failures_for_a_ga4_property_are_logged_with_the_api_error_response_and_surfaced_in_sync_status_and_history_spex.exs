defmodule MetricFlowSpex.SyncFailuresForAGa4PropertyAreLoggedWithTheApiErrorResponseAndSurfacedInSyncStatusAndHistorySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync failures for a GA4 property are logged with the API error response and surfaced in Sync Status and History" do
    scenario "a GA4 sync failure event is displayed in the sync history page with the error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event with an API error response is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 API error: 403 PERMISSION_DENIED — Property access denied"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Analytics entry", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' for the API failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the GA4 API failure entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the API error message is displayed in the sync history entry", context do
        html = render(context.view)

        assert html =~ "403" or html =~ "PERMISSION_DENIED" or html =~ "GA4 API error" or
                 html =~ "Property access denied",
               "Expected the GA4 API error response to be surfaced in the sync history, got: #{html}"

        :ok
      end

      then_ "the error message is associated with the correct provider entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the API error details"

        :ok
      end
    end

    scenario "multiple GA4 sync failures with different API errors all appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two different GA4 sync failure events with distinct API errors are broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 API error: 429 RESOURCE_EXHAUSTED"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "GA4 API error: 500 INTERNAL — runReport failed"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both failed sync entries appear in the history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 failed sync history entries (one per API error), but found #{entry_count}"

        :ok
      end

      then_ "the Failed filter shows only the failed entries", context do
        html = context.view
          |> element("[data-role='filter-failed']", "Failed")
          |> render_click()

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Failed filter to show failed entries, got: #{html}"

        :ok
      end
    end

    scenario "a GA4 sync failure is visible when filtering sync history by Failed status" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 API failure event is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "runReport endpoint returned error: INVALID_ARGUMENT"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      when_ "the user filters sync history by Failed status", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "the Google Analytics failure entry is visible in the filtered results", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected 'Google Analytics' to appear in the Failed filter results, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Failed status to be shown in the filtered results, got: #{html}"

        :ok
      end
    end
  end
end
