defmodule MetricFlowSpex.NoTrafficDayStoresAZeroValueRecordInsteadOfAGapSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "No-traffic day stores a zero-value record instead of a gap", criterion: 639 do
    scenario "a day with no GA4 traffic still results in a recorded sync entry" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 property had no traffic on a given day", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync processes that day", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a zero-value record is stored for that day rather than leaving a gap", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
