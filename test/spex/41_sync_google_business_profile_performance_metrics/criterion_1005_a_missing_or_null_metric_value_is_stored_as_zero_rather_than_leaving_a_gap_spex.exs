defmodule MetricFlowSpex.Criterion1005MissingOrNullMetricValueStoredAsZeroSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A missing or null metric value is stored as zero rather than leaving a gap", criterion: 1005 do
    scenario "a Google Business Profile location's API response omits a metric value for a day" do
      given_ :user_logged_in_as_owner

      given_ "a Google Business Profile location's performance response is missing a metric value for a day", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["locations/123456789"]}
        )

        {:ok, context}
      end

      when_ "the sync processes that day", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the missing value is stored as zero rather than leaving a gap", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Business Profile"
               )

        {:ok, context}
      end
    end
  end
end
