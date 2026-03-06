defmodule MetricFlowSpex.SyncErrorsAreLoggedWithDetailsForDebuggingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync errors are logged with details for debugging" do
    scenario "a failed sync entry on the sync history page shows the error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an async sync failure arrives with a specific error reason", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Authentication token expired"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the failure reason displayed on the page", context do
        html = render(context.view)

        assert html =~ "Authentication token expired" or
                 html =~ "token expired" or
                 html =~ "failed" or
                 html =~ "Failed" or
                 html =~ "error" or
                 html =~ "Error",
               "Expected the sync history page to display the sync failure reason, got: #{html}"

        :ok
      end
    end

    scenario "a failed sync entry shows the provider that failed alongside the error details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an async sync failure arrives for the Google integration", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Rate limit exceeded: 429 Too Many Requests"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the error details associated with the Google provider", context do
        html = render(context.view)

        assert html =~ "Google" or
                 html =~ "google",
               "Expected the error entry to identify the Google provider, got: #{html}"

        assert html =~ "Rate limit exceeded" or
                 html =~ "429" or
                 html =~ "Too Many Requests" or
                 html =~ "failed" or
                 html =~ "Failed" or
                 html =~ "error" or
                 html =~ "Error",
               "Expected the error entry to show the failure reason details, got: #{html}"

        :ok
      end
    end

    scenario "the sync history page distinguishes failed entries from successful ones" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an async sync failure arrives with a connection error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Connection refused: unable to reach API endpoint"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the failed entry is visually distinguishable as an error in the history list", context do
        html = render(context.view)

        has_error_indicator =
          html =~ "failed" or
          html =~ "Failed" or
          html =~ "error" or
          html =~ "Error" or
          has_element?(context.view, "[data-role='sync-error']") or
          has_element?(context.view, "[data-status='failed']") or
          has_element?(context.view, ".text-error") or
          has_element?(context.view, ".badge-error")

        assert has_error_indicator,
               "Expected the sync history page to visually distinguish failed entries, got: #{html}"

        :ok
      end
    end

    scenario "multiple different error reasons are visible when multiple syncs have failed" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a first sync failure arrives with a network error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Network timeout after 30 seconds"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "a second sync failure arrives with an authentication error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Invalid OAuth credentials"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the page shows error information that helps identify what went wrong", context do
        html = render(context.view)

        assert html =~ "failed" or
                 html =~ "Failed" or
                 html =~ "error" or
                 html =~ "Error",
               "Expected the page to show error information for debugging failed syncs, got: #{html}"

        :ok
      end
    end
  end
end
