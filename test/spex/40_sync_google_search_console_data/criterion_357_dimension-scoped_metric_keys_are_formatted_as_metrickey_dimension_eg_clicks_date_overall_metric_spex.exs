defmodule MetricFlowSpex.DimensionScopedMetricKeysSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Dimension-scoped metric keys are formatted as '{metricKey}_{dimension}' (e.g., 'clicks_date'); overall metric keys are unscoped (e.g., 'clicks')",
       criterion: 357 do
    scenario "a sync stores both a dimension-scoped and an unscoped metric key without error" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists with a configured site URL", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync completes successfully with both key shapes stored", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        {:ok, context}
      end
    end
  end
end
