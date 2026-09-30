defmodule MetricFlowSpex.Ga4QuotaLimitTriggersBackoffAndRetryThatSucceedsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "GA4 quota limit triggers backoff and retry that succeeds", criterion: 638 do
    scenario "a sync that hits the GA4 quota limit is retried with backoff and eventually succeeds" do
      given_ :user_logged_in_as_owner

      given_ "the sync hits the GA4 API's quota limit", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the request is retried with exponential backoff", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the request eventually succeeds within quota", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
