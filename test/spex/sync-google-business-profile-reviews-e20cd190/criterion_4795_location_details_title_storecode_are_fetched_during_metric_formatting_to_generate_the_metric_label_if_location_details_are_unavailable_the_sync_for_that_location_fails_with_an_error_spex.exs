defmodule MetricFlowSpex.LocationDetailsFetchedForMetricLabelOrSyncFailsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Location details fetched for metric label — unavailable details cause sync failure" do
    scenario "a successful sync includes location details in the sync history entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful Google Business Reviews sync event is broadcast with location details", context do
        Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync", {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 12,
          completed_at: DateTime.utc_now(),
          location_title: "Main Street Coffee",
          store_code: "MSC-001"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Google Business Reviews as the provider", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected sync history to show 'Google Business Reviews', got: #{html}"

        {:ok, context}
      end

      then_ "the sync history entry shows a Success status", context do
        html = render(context.view)

        assert html =~ "Success",
               "Expected the successful sync entry to be marked as Success, got: #{html}"

        {:ok, context}
      end

      then_ "the sync history entry shows the records synced count", context do
        html = render(context.view)

        assert html =~ "12",
               "Expected the sync entry to show 12 records synced, got: #{html}"

        {:ok, context}
      end
    end

    scenario "a sync failure due to unavailable location details appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync failure event is broadcast for a location without details", context do
        Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync", {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Location details unavailable for location — cannot generate metric label"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows a Failed status", context do
        html = render(context.view)

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as Failed, got: #{html}"

        {:ok, context}
      end

      then_ "the sync history entry shows Google Business Reviews as the provider", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected the failed sync entry to show 'Google Business Reviews', got: #{html}"

        {:ok, context}
      end
    end

    scenario "the error message for unavailable location details mentions the location details issue" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure event is broadcast indicating location details could not be fetched", context do
        Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync", {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Location details unavailable for location — cannot generate metric label"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the displayed error message references location details or metric label generation", context do
        html = render(context.view)

        assert html =~ "location" or html =~ "Location" or
                 html =~ "metric label" or html =~ "unavailable",
               "Expected the error to mention location details or metric label, got: #{html}"

        {:ok, context}
      end

      then_ "a sync-error element is rendered with the error details", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the location details error"

        {:ok, context}
      end
    end
  end
end
