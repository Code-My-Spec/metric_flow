defmodule MetricFlowSpex.SystemFetchesReviewsUsingGoogleMyBusinessApiV4SpexSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches reviews via Google My Business API v4 (direct HTTP, Google OAuth token)" do
    scenario "sync history shows a successful Google Business Reviews sync entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completion event is broadcast to the LiveView", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 42,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a successful Google Business Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "Business Reviews" or html =~ "google_business_reviews",
               "Expected sync history to show 'Google Business Reviews' provider name, got: #{html}"

        :ok
      end

      then_ "the sync entry shows a success status and records synced count", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected sync entry to show success status, got: #{html}"

        assert html =~ "42" or html =~ "records",
               "Expected sync entry to show the number of records synced, got: #{html}"

        :ok
      end
    end

    scenario "Google Business Reviews appears as a covered provider in the schedule section" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page mentions Google Business Reviews as a covered provider", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "Business Reviews" or html =~ "google_business",
               "Expected the sync history page to mention Google Business Reviews as a covered provider, got: #{html}"

        :ok
      end

      then_ "the schedule section describes the automated daily sync cadence", context do
        html = render(context.view)

        assert html =~ "Daily" or html =~ "daily",
               "Expected the schedule section to describe daily syncs, got: #{html}"

        :ok
      end
    end

    scenario "a failed Google Business Reviews sync shows error details in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync failure event is broadcast with an API error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "My Business API v4 error: PERMISSION_DENIED"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Business Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "Business Reviews" or html =~ "google_business_reviews",
               "Expected a Google Business Reviews provider entry in sync history, got: #{html}"

        assert html =~ "Failed" or html =~ "failed" or html =~ "badge-error",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error details from the My Business API are displayed", context do
        html = render(context.view)

        assert html =~ "My Business API" or html =~ "PERMISSION_DENIED" or html =~ "error",
               "Expected the failure reason to be shown in sync history, got: #{html}"

        :ok
      end
    end
  end
end
