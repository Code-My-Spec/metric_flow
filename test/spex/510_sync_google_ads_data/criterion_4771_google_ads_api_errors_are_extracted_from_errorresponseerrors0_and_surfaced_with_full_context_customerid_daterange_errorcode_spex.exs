defmodule MetricFlowSpex.GoogleAdsApiErrorsExtractedAndSurfacedWithFullContextSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Google Ads API errors extracted from error.response.errors[0] and surfaced with customerId, dateRange, errorCode" do
    scenario "a failed Google Ads sync shows the extracted error with full context details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast with full error context", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: PERMISSION_DENIED — customerId: 9876543210, dateRange: 2024-01-01..2024-01-31, errorCode: CUSTOMER_NOT_ENABLED"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' for the extracted-error failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error details include customerId or errorCode information", context do
        html = render(context.view)

        assert html =~ "customerId" or html =~ "9876543210" or
                 html =~ "CUSTOMER_NOT_ENABLED" or html =~ "PERMISSION_DENIED",
               "Expected the error details to include customerId or errorCode, got: #{html}"

        :ok
      end

      then_ "a sync-error element is present in the sync history", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the extracted API error details"

        :ok
      end
    end

    scenario "the sync-error element is present when a Google Ads API error is broadcast" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads failure event with errorCode details is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "errorCode: QUOTA_ERROR — customerId: 1111111111, dateRange: 2024-03-01..2024-03-15"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history contains a data-role sync-error element with error details", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected [data-role='sync-error'] element to be present after Google Ads API error"

        error_html = context.view
          |> element("[data-role='sync-error']")
          |> render()

        assert error_html =~ "QUOTA_ERROR" or error_html =~ "1111111111" or
                 error_html =~ "customerId" or error_html =~ "dateRange",
               "Expected the sync-error element to contain extracted error context, got: #{error_html}"

        :ok
      end
    end

    scenario "a failed sync with errorCode shows the error code in the history entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure is broadcast with a specific API errorCode", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "API error: REQUEST_ERROR — errorCode: INVALID_DATE_RANGE, customerId: 5555555555, dateRange: 2023-01-01..2023-12-31"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows the errorCode value", context do
        html = render(context.view)

        assert html =~ "INVALID_DATE_RANGE" or html =~ "REQUEST_ERROR" or
                 html =~ "5555555555" or html =~ "errorCode",
               "Expected the sync history to surface the API errorCode from error.response.errors[0], got: #{html}"

        :ok
      end

      then_ "the data-role sync-error element is present for the failed entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the Google Ads API error entry"

        :ok
      end
    end
  end
end
