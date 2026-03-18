defmodule MetricFlowSpex.SystemFetchesGoogleAdsDataUsingTheGoogleAdsApiViaTheGoogleAdsApiClientLibrarySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches Google Ads data using the Google Ads API client library, querying the customer entity with date segments" do
    scenario "a completed Google Ads sync appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast to the LiveView", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 42,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a successful Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' provider name, got: #{html}"

        :ok
      end

      then_ "the entry shows a success status with a record count", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a sync history entry with data-status='success'"

        assert html =~ "42",
               "Expected sync history entry to show the records synced count of 42, got: #{html}"

        :ok
      end
    end

    scenario "the sync schedule section mentions Google Ads as a covered provider" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the automated sync schedule section lists Google Ads as a covered marketing provider", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected the sync schedule section to mention 'Google Ads', got: #{html}"

        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected a [data-role='sync-schedule'] element describing the automated schedule"

        :ok
      end
    end

    scenario "a failed Google Ads sync surfaces error details in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast with an API error reason", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: INVALID_CUSTOMER_ID — customer entity query failed"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected a Google Ads provider entry in sync history, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected a sync history entry with data-status='failed'"

        :ok
      end

      then_ "the error details from the API are displayed on the entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the API error details"

        html = render(context.view)

        assert html =~ "Google Ads API error" or html =~ "INVALID_CUSTOMER_ID" or html =~ "customer entity",
               "Expected the Google Ads API error message to be displayed, got: #{html}"

        :ok
      end
    end
  end
end
