defmodule MetricFlowSpex.SystemHandlesGa4ApiQuotaLimitsWithBackoffAndRetrySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System handles GA4 API quota limits with exponential backoff and retry (default quota: 10 requests/second/project)",
       criterion: 298 do
    scenario "a sync that hits the GA4 quota limit retries with backoff and eventually succeeds" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property whose first request would exceed the quota limit", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync runs and the quota-limited request is retried", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync ultimately succeeds despite the quota limit", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
