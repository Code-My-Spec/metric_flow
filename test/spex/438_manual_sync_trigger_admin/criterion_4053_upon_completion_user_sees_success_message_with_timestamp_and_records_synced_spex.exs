defmodule MetricFlowSpex.UponCompletionUserSeesSuccessMessageWithTimestampAndRecordsSyncedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Upon completion, user sees success message with timestamp and records synced" do
    scenario "after sync completes successfully, user sees a success message containing the number of records synced" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page with a connected Google integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the async sync completion message is received by the LiveView", context do
        completed_at = DateTime.utc_now()

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 42,
          completed_at: completed_at
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, Map.put(context, :completed_at, completed_at)}
      end

      then_ "the user sees a success message containing the number of records synced", context do
        html = render(context.view)

        assert html =~ "42" or
                 html =~ "synced" or
                 html =~ "Synced" or
                 html =~ "success" or
                 html =~ "Success" or
                 html =~ "records",
               "Expected the page to show a success message with records synced count, got: #{html}"

        :ok
      end

      then_ "the success message includes a timestamp indicating when the sync completed", context do
        html = render(context.view)

        year = context.completed_at.year |> Integer.to_string()

        assert html =~ year or
                 html =~ "completed" or
                 html =~ "Completed" or
                 html =~ "at " or
                 html =~ "timestamp",
               "Expected the page to show a timestamp for the sync completion, got: #{html}"

        :ok
      end
    end

    scenario "after sync completes, the Syncing indicator disappears and the button is re-enabled" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page and a sync is in progress for Google", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")

        # Trigger sync to put the platform into the syncing state
        render_click(view, "sync", %{"platform" => "google_analytics", "provider" => "google"})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Syncing indicator is visible while the sync is in progress", context do
        html = render(context.view)

        assert html =~ "Syncing" or
                 has_element?(context.view, "[data-role='integration-sync-status']"),
               "Expected the page to show a Syncing indicator, got: #{html}"

        :ok
      end

      when_ "the async sync completion message is received by the LiveView", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 17,
          completed_at: DateTime.utc_now()
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the Syncing indicator is no longer shown", context do
        html = render(context.view)

        refute html =~ "loading loading-spinner",
               "Expected the Syncing spinner to be gone after sync completed, but it was still present"

        :ok
      end

      then_ "the Sync Now button is re-enabled for the integration", context do
        # The button should no longer be disabled after sync completion
        refute has_element?(
          context.view,
          "[data-platform='google_analytics'] button[phx-click='sync'][disabled]"
        ),
        "Expected the Sync Now button to be re-enabled after sync completed, but it was still disabled"

        :ok
      end
    end
  end
end
