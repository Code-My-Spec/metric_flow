defmodule MetricFlowSpex.SampledGa4ResponseIsFlaggedWithAWarningAndCaveatSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sampled GA4 response is flagged with a warning and caveat", criterion: 637 do
    scenario "a sampled response is flagged when the sync processes it" do
      given_ :user_logged_in_as_owner

      given_ "the GA4 API returns a sampled data response", context do
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

      then_ "a warning is logged and the stored data carries a sampling caveat", context do
        assert has_element?(context.view, "[data-role='sampling-caveat']")
        {:ok, context}
      end
    end
  end
end
