defmodule MetricFlowSpex.SampledDataResponsesAreDetectedAndFlaggedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sampled data responses are detected and flagged — system logs a warning and stores data with a sampling caveat",
       criterion: 297 do
    scenario "a sampled GA4 response is flagged with a sampling caveat in sync history" do
      given_ :user_logged_in_as_owner

      given_ "the GA4 API returns a sampled data response for a connected property", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync processes that response", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history entry carries a sampling caveat", context do
        assert has_element?(context.view, "[data-role='sampling-caveat']")
        {:ok, context}
      end
    end
  end
end
