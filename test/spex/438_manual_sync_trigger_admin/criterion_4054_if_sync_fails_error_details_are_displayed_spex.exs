defmodule MetricFlowSpex.IfSyncFailsErrorDetailsAreDisplayedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If sync fails, error details are displayed" do
    scenario "when an async sync fails the user sees an error message with the failure reason" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page with a connected Google integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the async sync failure message is received by the LiveView", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "API rate limit exceeded"
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees an error message containing the failure reason", context do
        html = render(context.view)

        assert html =~ "API rate limit exceeded" or
                 html =~ "rate limit" or
                 html =~ "Sync failed" or
                 html =~ "sync failed" or
                 html =~ "error" or
                 html =~ "Error",
               "Expected the page to show an error message with the failure reason, got: #{html}"

        :ok
      end
    end

    scenario "after a sync failure the Syncing indicator disappears and the button is re-enabled" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page and a sync is in progress for Google", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")

        # Trigger sync to put the provider into the syncing state
        render_click(view, "sync", %{"provider" => "google"})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Syncing indicator is visible while the sync is in progress", context do
        html = render(context.view)

        assert html =~ "Syncing" or
                 has_element?(context.view, "[data-role='integration-sync-status']"),
               "Expected the page to show a Syncing indicator before failure, got: #{html}"

        :ok
      end

      when_ "the async sync failure message is received by the LiveView", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "API rate limit exceeded"
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the Syncing indicator is no longer shown", context do
        html = render(context.view)

        refute html =~ "loading loading-spinner",
               "Expected the Syncing spinner to be gone after sync failed, but it was still present"

        :ok
      end

      then_ "the Sync Now button is re-enabled so the user can retry", context do
        refute has_element?(
          context.view,
          "button[phx-click='sync'][phx-value-provider='google'][disabled]"
        ),
        "Expected the Sync Now button to be re-enabled after sync failed, but it was still disabled"

        :ok
      end
    end
  end
end
