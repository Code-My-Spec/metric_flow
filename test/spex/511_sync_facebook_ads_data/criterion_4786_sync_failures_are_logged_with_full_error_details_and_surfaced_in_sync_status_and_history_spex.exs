defmodule MetricFlowSpex.SyncFailuresAreLoggedWithFullErrorDetailsAndSurfacedInSyncStatusAndHistorySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync failures are logged with full error details and surfaced in Sync Status and History" do
    scenario "a Facebook Ads sync failure event is displayed in the sync history page with the error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event with an API error response is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Ads API error: 190 Invalid OAuth access token — The session has been invalidated"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' for the API failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Facebook Ads API failure entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the API error message is displayed in the sync history entry", context do
        html = render(context.view)

        assert html =~ "190" or html =~ "Invalid OAuth access token" or
                 html =~ "Facebook Ads API error" or html =~ "session has been invalidated",
               "Expected the Facebook Ads API error response to be surfaced in the sync history, got: #{html}"

        :ok
      end

      then_ "the error message is associated with the correct provider entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the API error details"

        :ok
      end
    end

    scenario "multiple Facebook Ads sync failures with different API errors all appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two different Facebook Ads sync failure events with distinct API errors are broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Ads API error: 17 User request limit reached"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Ads API error: 100 Invalid parameter — act_123456 is not a valid account"
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

    scenario "a Facebook Ads sync failure shows specific API error details rather than a generic message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads API failure event with a specific error code is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Ads API error: 200 Permission error — (#200) The user hasn't authorized the application to perform this action"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows the specific Facebook API error, not a generic message", context do
        html = render(context.view)

        refute html =~ "Something went wrong" and not (html =~ "200" or html =~ "Permission error" or
                 html =~ "Facebook Ads API error"),
               "Expected specific Facebook API error details to be shown, not a generic message"

        assert html =~ "200" or html =~ "Permission error" or html =~ "application to perform this action",
               "Expected specific Facebook API error details in the sync history entry, got: #{html}"

        :ok
      end
    end

    scenario "a Facebook Ads sync failure is visible when filtering sync history by Failed status" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads API failure event is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Facebook Ads API error: 368 The action attempted has been deemed abusive or is otherwise disallowed"
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

      then_ "the Facebook Ads failure entry is visible in the filtered results", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected 'Facebook Ads' to appear in the Failed filter results, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Failed status to be shown in the filtered results, got: #{html}"

        :ok
      end
    end
  end
end
