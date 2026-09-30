defmodule MetricFlowSpex.StoredDataIsScopedToDateOnlyWithNoOtherDimensionsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Stored data is scoped to date only, with no other dimensions", criterion: 643 do
    scenario "GA4 metrics stored for a property carry no source/medium breakdown" do
      given_ :user_logged_in_as_owner

      given_ "GA4 metrics are stored for a property", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      given_ :with_google_analytics_sync_stub

      when_ "the records are written", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they are scoped to the date range dimension only, with no source/medium or other dimension breakdowns",
            context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        refute html =~ "source/medium"
        {:ok, context}
      end
    end
  end
end
