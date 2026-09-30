defmodule MetricFlowSpex.SystemSyncsAllCoreGa4MetricsAsDailyValuesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  @core_metrics ~w(activeUsers active7DayUsers active28DayUsers newUsers engagedSessions
                   sessions userEngagementDuration screenPageViews eventCount keyEvents scrolledUsers)

  @moduledoc """
  Core metric list: #{Enum.join(@core_metrics, ", ")}.
  """

  spex "System syncs the following GA4 metrics as core daily values: activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers",
       criterion: 293 do
    scenario "a daily sync records a value for every core metric" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property with normal traffic", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync entry reports records synced covering all #{length(@core_metrics)} core metrics for the day",
            context do
        assert has_element?(context.view, "[data-role='sync-history-entry'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
