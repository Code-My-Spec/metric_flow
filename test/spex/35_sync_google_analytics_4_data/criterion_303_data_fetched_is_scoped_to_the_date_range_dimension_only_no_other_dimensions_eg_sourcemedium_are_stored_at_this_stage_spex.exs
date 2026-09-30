defmodule MetricFlowSpex.DataFetchedIsScopedToTheDateDimensionOnlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Data fetched is scoped to the date range dimension only — no other dimensions (e.g., source/medium) are stored at this stage",
       criterion: 303 do
    scenario "a completed GA4 sync stores plain daily values without a dimension breakdown" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync completes successfully without a source/medium breakdown appearing in the entry", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        refute html =~ "source/medium"
        {:ok, context}
      end
    end
  end
end
